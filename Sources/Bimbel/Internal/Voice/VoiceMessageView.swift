import AVFoundation
import UIKit

/// Voice bubble: play accent circle 32 · waveform 24 · duration · speed chip 1× / 1.5× / 2×.
final class VoiceMessageView: UIView, AVAudioPlayerDelegate {
    private let playHost = UIView()
    private let playFill = ComposerAccentCircle()
    private let play = HitTargetButton(type: .system)
    private let wave = WaveformView()
    private let durationLabel = UILabel()
    private let speedButton = HitTargetButton(type: .system)
    private var voice = Voice(duration: 0)
    private var theme = ConversationTheme.default
    private var player: AVAudioPlayer?
    private var rate: VoicePlaybackRate = .one
    /// Main-thread only. `nonisolated(unsafe)` so Swift 6 `deinit` can invalidate.
    private nonisolated(unsafe) var displayLink: CADisplayLink?
    private var objectToken = UUID()
    private var playSize: NSLayoutConstraint!
    private var fillSize: NSLayoutConstraint!
    private var fillHeight: NSLayoutConstraint!
    private var waveHeight: NSLayoutConstraint!

    override init(frame: CGRect) {
        super.init(frame: frame)
        wave.backgroundColor = .clear
        durationLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)

        playHost.backgroundColor = .clear
        playFill.isUserInteractionEnabled = false
        play.backgroundColor = .clear
        play.setImage(UIImage.bimbelComposerLine("play.fill"), for: .normal)
        play.addTarget(self, action: #selector(togglePlay), for: .touchUpInside)
        play.accessibilityLabel = String(localized: "Play voice message")
        play.minimumHitSize = CGSize(width: 44, height: 44)
        playHost.addSubview(playFill)
        playHost.addSubview(play)
        playFill.translatesAutoresizingMaskIntoConstraints = false
        play.translatesAutoresizingMaskIntoConstraints = false
        playSize = playHost.widthAnchor.constraint(equalToConstant: 44)
        fillSize = playFill.widthAnchor.constraint(equalToConstant: 32)
        fillHeight = playFill.heightAnchor.constraint(equalToConstant: 32)
        NSLayoutConstraint.activate([
            playSize,
            playHost.heightAnchor.constraint(equalToConstant: 44),
            fillSize,
            fillHeight,
            playFill.centerXAnchor.constraint(equalTo: playHost.centerXAnchor),
            playFill.centerYAnchor.constraint(equalTo: playHost.centerYAnchor),
            play.topAnchor.constraint(equalTo: playHost.topAnchor),
            play.leadingAnchor.constraint(equalTo: playHost.leadingAnchor),
            play.trailingAnchor.constraint(equalTo: playHost.trailingAnchor),
            play.bottomAnchor.constraint(equalTo: playHost.bottomAnchor)
        ])

        speedButton.addTarget(self, action: #selector(cycleSpeed), for: .touchUpInside)
        speedButton.accessibilityLabel = String(localized: "Playback speed")
        speedButton.minimumHitSize = CGSize(width: 44, height: 32)
        speedButton.contentEdgeInsets = UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)
        speedButton.layer.masksToBounds = true
        applySpeedTitle()

        let stack = UIStackView(arrangedSubviews: [playHost, wave, durationLabel, speedButton])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 8
        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        waveHeight = wave.heightAnchor.constraint(equalToConstant: 24)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            wave.widthAnchor.constraint(equalToConstant: 96),
            waveHeight,
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
        displayLink?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        speedButton.layer.cornerRadius = speedButton.bounds.height > 1 ? speedButton.bounds.height / 2 : 10
        speedButton.layer.cornerCurve = .continuous
    }

    func configure(_ voice: Voice, theme: ConversationTheme) {
        self.voice = voice
        self.theme = theme
        play.tintColor = theme.colors.sendIcon
        playFill.backgroundColor = theme.colors.accent
        speedButton.titleLabel?.font = theme.fonts.voiceSpeed
        speedButton.setTitleColor(theme.colors.headerSubtitle, for: .normal)
        speedButton.backgroundColor = theme.colors.secondaryFill
        wave.tintColor = theme.colors.waveform
        wave.playedTintColor = theme.colors.waveformPlayed
        durationLabel.textColor = theme.colors.headerSubtitle
        durationLabel.text = BimbelFormatters.duration(voice.duration)
        wave.setSamples(voice.waveform)
        fillSize.constant = theme.layout.voicePlaySize
        fillHeight.constant = theme.layout.voicePlaySize
        waveHeight.constant = theme.layout.voiceWaveformHeight
        if player?.isPlaying != true {
            applyPlayIcon(playing: false)
            wave.progress = 0
        }
    }

    func resetPlayback() {
        stop(resetClock: true)
    }

    @objc private func togglePlay() {
        if player?.isPlaying == true {
            player?.pause()
            applyPlayIcon(playing: false)
            stopTick()
            return
        }
        guard let url = voice.fileURL else {
            applyPlayIcon(playing: true)
            wave.progress = 0.35
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.applyPlayIcon(playing: false)
                self?.wave.progress = 0
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
        stopTick()
        let link = CADisplayLink(target: self, selector: #selector(pulsePlayback))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 10, maximum: 20, preferred: 15)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopTick() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func pulsePlayback() {
        guard let player, player.isPlaying else { return }
        let remaining = max(0, player.duration - player.currentTime)
        durationLabel.text = BimbelFormatters.duration(remaining)
        let total = max(player.duration, 0.001)
        wave.progress = CGFloat(player.currentTime / total)
    }

    private func stop(resetClock: Bool) {
        player?.stop()
        player = nil
        stopTick()
        applyPlayIcon(playing: false)
        wave.progress = 0
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
