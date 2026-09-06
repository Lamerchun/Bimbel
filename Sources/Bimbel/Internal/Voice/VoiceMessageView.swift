import AVFoundation
import UIKit

/// Voice bubble: waveform · duration · play/pause · speed 1× / 1.5× / 2×.
final class VoiceMessageView: UIView, AVAudioPlayerDelegate {
    private let play = HitTargetButton(type: .system)
    private let wave = WaveformView()
    private let durationLabel = UILabel()
    private let speedButton = HitTargetButton(type: .system)
    private var voice = Voice(duration: 0)
    private var theme = ConversationTheme.default
    private var player: AVAudioPlayer?
    private var rate: VoicePlaybackRate = .one
    private var tick: Timer?
    private var objectToken = UUID()

    override init(frame: CGRect) {
        super.init(frame: frame)
        wave.backgroundColor = .clear
        durationLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        play.setImage(UIImage.bimbelComposerLine("play.fill"), for: .normal)
        play.addTarget(self, action: #selector(togglePlay), for: .touchUpInside)
        play.accessibilityLabel = String(localized: "Play voice message")
        play.minimumHitSize = CGSize(width: 44, height: 44)

        speedButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .semibold)
        speedButton.addTarget(self, action: #selector(cycleSpeed), for: .touchUpInside)
        speedButton.accessibilityLabel = String(localized: "Playback speed")
        speedButton.minimumHitSize = CGSize(width: 44, height: 32)
        applySpeedTitle()

        let stack = UIStackView(arrangedSubviews: [play, wave, durationLabel, speedButton])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 8
        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            wave.widthAnchor.constraint(equalToConstant: 96),
            wave.heightAnchor.constraint(equalToConstant: 22),
            play.widthAnchor.constraint(equalToConstant: 28),
            play.heightAnchor.constraint(equalToConstant: 28),
            speedButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 36)
        ])

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(otherWillPlay(_:)),
            name: .bimbelVoiceWillPlay,
            object: nil
        )
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        tick?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    func configure(_ voice: Voice, theme: ConversationTheme) {
        self.voice = voice
        self.theme = theme
        play.tintColor = theme.colors.accent
        speedButton.tintColor = theme.colors.accent
        speedButton.setTitleColor(theme.colors.accent, for: .normal)
        wave.tintColor = theme.colors.waveformAccent
        durationLabel.textColor = theme.colors.metadata
        durationLabel.text = BimbelFormatters.duration(voice.duration)
        wave.setSamples(voice.waveform)
        if player?.isPlaying != true {
            applyPlayIcon(playing: false)
        }
    }

    func resetPlayback() {
        stop(resetClock: true)
    }

    @objc private func togglePlay() {
        if player?.isPlaying == true {
            player?.pause()
            applyPlayIcon(playing: false)
            tick?.invalidate()
            return
        }
        guard let url = voice.fileURL else {
            applyPlayIcon(playing: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.applyPlayIcon(playing: false)
            }
            return
        }
        NotificationCenter.default.post(name: .bimbelVoiceWillPlay, object: objectToken)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
            if player == nil {
                let next = try AVAudioPlayer(contentsOf: url)
                next.delegate = self
                next.enableRate = true
                player = next
            }
            player?.rate = rate.value
            player?.play()
            applyPlayIcon(playing: true)
            startTick()
        } catch {
            applyPlayIcon(playing: false)
        }
    }

    @objc private func cycleSpeed() {
        rate = rate.next()
        player?.enableRate = true
        player?.rate = rate.value
        applySpeedTitle()
    }

    @objc private func otherWillPlay(_ notification: Notification) {
        guard notification.object as? UUID != objectToken else { return }
        stop(resetClock: true)
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.stop(resetClock: true)
        }
    }

    private func startTick() {
        tick?.invalidate()
        tick = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, let player = self.player, player.isPlaying else { return }
                let remaining = max(0, player.duration - player.currentTime)
                self.durationLabel.text = BimbelFormatters.duration(remaining)
            }
        }
    }

    private func stop(resetClock: Bool) {
        player?.stop()
        player = nil
        tick?.invalidate()
        tick = nil
        applyPlayIcon(playing: false)
        if resetClock {
            durationLabel.text = BimbelFormatters.duration(voice.duration)
        }
    }

    private func applyPlayIcon(playing: Bool) {
        play.setImage(UIImage.bimbelComposerLine(playing ? "pause.fill" : "play.fill"), for: .normal)
        play.accessibilityLabel = playing
            ? String(localized: "Pause voice message")
            : String(localized: "Play voice message")
    }

    private func applySpeedTitle() {
        speedButton.setTitle(rate.label, for: .normal)
        speedButton.accessibilityValue = rate.label
    }
}
