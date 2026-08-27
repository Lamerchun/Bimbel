import UIKit

final class ConversationHeaderView: UIView {
    var onBack: (() -> Void)?
    var onTitleTap: (() -> Void)?
    var onVideo: (() -> Void)?
    var onCall: (() -> Void)?

    private let glass = MaterialFactory.makeHeaderEffectView(theme: .default)
    private let content = UIView()
    private let backButton = HitTargetButton(type: .system)
    private let badgeLabel = UILabel()
    private let avatarView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleRow = UIStackView()
    private let typingDots = TypingDotsView()
    private let subtitleLabel = UILabel()
    private let videoButton = HitTargetButton(type: .system)
    private let callButton = HitTargetButton(type: .system)
    private var heightConstraint: NSLayoutConstraint?
    private var theme = ConversationTheme.default

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup() {
        backgroundColor = .clear
        // No hairline: never set a bottom border or shadow.
        addSubview(glass)
        glass.bimbelPinToEdges(of: self)

        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)

        backButton.setImage(UIImage(systemName: "chevron.backward"), for: .normal)
        backButton.addTarget(self, action: #selector(tapBack), for: .touchUpInside)
        backButton.accessibilityLabel = "Back"

        badgeLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        badgeLabel.textAlignment = .center
        badgeLabel.layer.cornerRadius = 8
        badgeLabel.layer.masksToBounds = true
        badgeLabel.isHidden = true

        avatarView.contentMode = .scaleAspectFill
        avatarView.layer.cornerRadius = 16
        avatarView.layer.masksToBounds = true
        avatarView.isUserInteractionEnabled = true
        avatarView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapTitle)))

        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.adjustsFontSizeToFitWidth = false
        titleLabel.minimumScaleFactor = 1
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        subtitleLabel.numberOfLines = 1
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.adjustsFontSizeToFitWidth = false
        subtitleLabel.minimumScaleFactor = 1
        subtitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        subtitleRow.axis = .horizontal
        subtitleRow.alignment = .center
        subtitleRow.spacing = 6
        subtitleRow.addArrangedSubview(typingDots)
        subtitleRow.addArrangedSubview(subtitleLabel)
        typingDots.isHidden = true

        let identity = UIStackView(arrangedSubviews: [titleLabel, subtitleRow])
        identity.axis = .vertical
        identity.alignment = .leading
        identity.spacing = 1
        identity.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        identity.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapTitle)))
        identity.isUserInteractionEnabled = true

        videoButton.setImage(UIImage(systemName: "video"), for: .normal)
        videoButton.addTarget(self, action: #selector(tapVideo), for: .touchUpInside)
        videoButton.accessibilityLabel = "Video"

        callButton.setImage(UIImage(systemName: "phone"), for: .normal)
        callButton.addTarget(self, action: #selector(tapCall), for: .touchUpInside)
        callButton.accessibilityLabel = "Call"

        [backButton, badgeLabel, avatarView, identity, videoButton, callButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview($0)
        }

        heightConstraint = content.heightAnchor.constraint(equalToConstant: 44)

        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: leadingAnchor),
            content.trailingAnchor.constraint(equalTo: trailingAnchor),
            content.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightConstraint!,

            backButton.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 4),
            backButton.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44),

            badgeLabel.leadingAnchor.constraint(equalTo: backButton.centerXAnchor, constant: 4),
            badgeLabel.topAnchor.constraint(equalTo: backButton.topAnchor, constant: 4),
            badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 16),
            badgeLabel.heightAnchor.constraint(equalToConstant: 16),

            avatarView.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 2),
            avatarView.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 32),
            avatarView.heightAnchor.constraint(equalToConstant: 32),

            callButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -6),
            callButton.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            callButton.widthAnchor.constraint(equalToConstant: 44),
            callButton.heightAnchor.constraint(equalToConstant: 44),

            videoButton.trailingAnchor.constraint(equalTo: callButton.leadingAnchor, constant: -2),
            videoButton.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            videoButton.widthAnchor.constraint(equalToConstant: 44),
            videoButton.heightAnchor.constraint(equalToConstant: 44),

            identity.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 8),
            identity.trailingAnchor.constraint(lessThanOrEqualTo: videoButton.leadingAnchor, constant: -8),
            identity.centerYAnchor.constraint(equalTo: content.centerYAnchor)
        ])

        // Trailing icons and Back do not yield width; identity compresses.
        backButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        videoButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        callButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        identity.setContentHuggingPriority(.defaultLow, for: .horizontal)
    }

    func apply(content header: HeaderContent, theme: ConversationTheme) {
        self.theme = theme
        tintColor = theme.colors.headerTitle
        titleLabel.font = theme.fonts.headerTitle
        titleLabel.textColor = theme.colors.headerTitle
        titleLabel.text = header.title
        subtitleLabel.font = theme.fonts.headerSubtitle
        subtitleLabel.textColor = theme.colors.headerSubtitle
        subtitleLabel.text = header.subtitle
        subtitleLabel.isHidden = (header.subtitle ?? "").isEmpty && !header.isTyping

        typingDots.isHidden = !header.isTyping
        typingDots.tintColor = theme.colors.headerSubtitle
        if header.isTyping { typingDots.start() } else { typingDots.stop() }

        let tall = header.subtitle != nil || header.isTyping
        heightConstraint?.constant = tall ? theme.layout.headerHeightTall : theme.layout.headerHeightCompact
        // Typing uses the subtitle row; height stays 56. No extra height animation.

        if let image = ImageLoader.image(from: header.avatar) {
            avatarView.image = image
        } else if let avatar = header.avatar {
            ImageLoader.load(avatar) { [weak self] image in
                self?.avatarView.image = image ?? InitialGlyph.make(title: header.title, size: 32, colors: theme.colors)
            }
        } else {
            avatarView.image = InitialGlyph.make(title: header.title, size: 32, colors: theme.colors)
            avatarView.tintColor = .white
        }

        if let badge = BimbelFormatters.badgeText(header.unreadBadge) {
            badgeLabel.isHidden = false
            badgeLabel.text = " \(badge) "
            badgeLabel.textColor = theme.colors.badgeText
            badgeLabel.backgroundColor = theme.colors.badgeFill
        } else {
            badgeLabel.isHidden = true
        }

        if header.showsUnifiedCall {
            videoButton.isHidden = true
            callButton.isHidden = false
            callButton.setImage(UIImage(systemName: "phone.fill"), for: .normal)
            callButton.accessibilityLabel = "Call"
        } else {
            videoButton.isHidden = !header.showsVideo
            callButton.isHidden = !header.showsCall
            callButton.setImage(UIImage(systemName: "phone"), for: .normal)
            videoButton.setImage(UIImage(systemName: "video"), for: .normal)
        }

        backButton.tintColor = theme.colors.headerTitle
        videoButton.tintColor = theme.colors.headerTitle
        callButton.tintColor = theme.colors.headerTitle
    }

    @objc private func tapBack() { onBack?() }
    @objc private func tapTitle() { onTitleTap?() }
    @objc private func tapVideo() { onVideo?() }
    @objc private func tapCall() { onCall?() }
}

final class TypingDotsView: UIView {
    private var displayLink: CADisplayLink?
    private var phase: CGFloat = 0

    override var intrinsicContentSize: CGSize { CGSize(width: 22, height: 10) }

    override func draw(_ rect: CGRect) {
        guard let color = tintColor else { return }
        let y = bounds.midY
        let spacing: CGFloat = 7
        let startX = bounds.midX - spacing
        for i in 0..<3 {
            let pulse = (sin(phase + CGFloat(i) * 0.9) + 1) / 2
            let radius: CGFloat = 1.6 + pulse * 1.1
            let alpha: CGFloat = 0.35 + pulse * 0.65
            color.withAlphaComponent(alpha).setFill()
            UIBezierPath(
                ovalIn: CGRect(x: startX + CGFloat(i) * spacing - radius, y: y - radius, width: radius * 2, height: radius * 2)
            ).fill()
        }
    }

    func start() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        setNeedsDisplay()
    }

    @objc private func tick(link: CADisplayLink) {
        phase += 0.18
        setNeedsDisplay()
    }

    deinit { displayLink?.invalidate() }
}
