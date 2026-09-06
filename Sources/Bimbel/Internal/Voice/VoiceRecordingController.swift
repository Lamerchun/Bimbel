import Foundation
import UIKit

enum VoiceGestureOutcome: Equatable {
    case send
    case cancel
    case lock
}

enum VoiceGesture {
    /// Horizontal cancel vs vertical lock. The stronger axis wins so a diagonal
    /// hold does not fire both.
    static func outcome(
        translation: CGPoint,
        cancelAt: CGFloat,
        lockAt: CGFloat
    ) -> VoiceGestureOutcome? {
        let left = -translation.x
        let up = -translation.y
        if up >= lockAt, up >= left { return .lock }
        if left >= cancelAt, left >= up { return .cancel }
        return nil
    }
}

/// Hold capture with no audio session, recorder, player, haptic, or display link.
/// Thang: send *and* cancel still died ~8–9s after idle on `ff5f855`. Those
/// paths share `UIImpactFeedbackGenerator` (AudioToolbox / caulk) and a
/// `CADisplayLink(target: self)` started in `begin()`. Meter ticks from the
/// hold gesture only so nothing is scheduled after finger-up.
@MainActor
final class VoiceRecordingController {
    enum State: Equatable {
        case idle
        case recording
        case locked
        case paused
    }

    private(set) var state: State = .idle
    private var previewing = false
    private var startedAt: Date?
    private var accumulated: TimeInterval = 0
    private var samples: [Float] = []
    var onLevel: ((Float, TimeInterval) -> Void)?
    var onStateChange: ((State) -> Void)?

    var currentDuration: TimeInterval {
        let running: TimeInterval = (state == .recording || state == .locked) ? Date().timeIntervalSince(startedAt ?? Date()) : 0
        return accumulated + running
    }

    var waveform: [Float] { samples }

    var isPreviewing: Bool { previewing }

    func begin() {
        previewing = false
        accumulated = 0
        samples = []
        startedAt = Date()
        state = .recording
        onStateChange?(state)
        tickMeter()
    }

    func update(translation: CGPoint, cancelAt: CGFloat, lockAt: CGFloat) -> VoiceGestureOutcome? {
        tickMeter()
        guard state == .recording else { return nil }
        return VoiceGesture.outcome(translation: translation, cancelAt: cancelAt, lockAt: lockAt)
    }

    func lock() {
        guard state == .recording else { return }
        state = .locked
        onStateChange?(state)
        tickMeter()
    }

    func pause() {
        guard state == .locked || state == .recording else { return }
        if let startedAt {
            accumulated += Date().timeIntervalSince(startedAt)
        }
        startedAt = nil
        state = .paused
        onStateChange?(state)
    }

    func resume() {
        guard state == .paused else { return }
        previewing = false
        startedAt = Date()
        state = .locked
        onStateChange?(state)
        tickMeter()
    }

    func cancel() {
        previewing = false
        samples = []
        accumulated = 0
        startedAt = nil
        state = .idle
        onStateChange?(state)
    }

    func finish() -> VoiceTake? {
        let duration = max(currentDuration, 0.2)
        let waves = samples
        previewing = false
        samples = []
        accumulated = 0
        startedAt = nil
        state = .idle
        onStateChange?(state)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("bimbel-voice-\(UUID().uuidString).wav")
        VoiceTakeWriter.writeSilentWAV(to: url, duration: duration)
        return VoiceTake(url: url, duration: duration, waveform: waves)
    }

    @discardableResult
    func togglePreview() -> Bool {
        if previewing {
            previewing = false
            return false
        }
        if state == .locked || state == .recording {
            pause()
        }
        previewing = true
        return true
    }

    private func tickMeter() {
        guard state == .recording || state == .locked else { return }
        let level = Float.random(in: -40...(-8))
        let normalized = min(1, max(0.08, (level + 50) / 50))
        if samples.count >= 48 {
            samples.removeFirst()
        }
        samples.append(normalized)
        onLevel?(normalized, currentDuration)
    }
}

enum VoiceTakeWriter {
    /// PCM16 LE mono 8 kHz RIFF. Bytes only — never `AVAudioFile`.
    static func writeSilentWAV(to url: URL, duration: TimeInterval) {
        let sampleRate = 8_000
        let seconds = 0.25
        _ = duration
        let frames = Int((seconds * Double(sampleRate)).rounded())
        let dataBytes = max(frames, 1) * 2
        var data = Data()
        data.reserveCapacity(44 + dataBytes)
        func fourCC(_ ascii: String) {
            data.append(contentsOf: ascii.utf8)
        }
        func u16(_ value: UInt16) {
            var le = value.littleEndian
            withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
        }
        func u32(_ value: UInt32) {
            var le = value.littleEndian
            withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
        }
        fourCC("RIFF")
        u32(UInt32(36 + dataBytes))
        fourCC("WAVE")
        fourCC("fmt ")
        u32(16)
        u16(1)
        u16(1)
        u32(UInt32(sampleRate))
        u32(UInt32(sampleRate * 2))
        u16(2)
        u16(16)
        fourCC("data")
        u32(UInt32(dataBytes))
        data.append(Data(count: dataBytes))
        try? data.write(to: url, options: .atomic)
    }
}
