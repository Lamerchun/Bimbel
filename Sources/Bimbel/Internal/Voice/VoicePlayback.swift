import AVFoundation
import UIKit

enum VoicePlaybackRate: Equatable, CaseIterable {
    case one
    case oneAndHalf
    case two

    var value: Float {
        switch self {
        case .one: return 1
        case .oneAndHalf: return 1.5
        case .two: return 2
        }
    }

    var label: String {
        switch self {
        case .one: return "1×"
        case .oneAndHalf: return "1.5×"
        case .two: return "2×"
        }
    }

    func next() -> VoicePlaybackRate {
        switch self {
        case .one: return .oneAndHalf
        case .oneAndHalf: return .two
        case .two: return .one
        }
    }
}

extension Notification.Name {
    static let bimbelVoiceWillPlay = Notification.Name("bimbel.voice.willPlay")
}

struct VoiceTake: Equatable {
    var url: URL
    var duration: TimeInterval
    var waveform: [Float]
}
