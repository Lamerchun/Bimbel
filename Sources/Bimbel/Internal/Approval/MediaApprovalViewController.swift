import AVFoundation
import PhotosUI
import UIKit

final class MediaApprovalViewController: UIViewController, MediaEditorDelegate, UITextFieldDelegate {
    var onSend: ((EditSession) -> Void)?
    var onAddMore: ((MediaApprovalViewController) -> Void)?
    var onCancel: (() -> Void)?

    private(set) var session: EditSession
    private let theme: ConversationTheme
    private let preview = UIImageView()
    private let playerView = ApprovalPlayerView()
    private let trimSlider = VideoTrimControl()
    private var trimHeight: NSLayoutConstraint!
    private let toolbar = UIStackView()
    private let captionField = UITextField()
    private let captionFill = UIView()
    private let sendButton = HitTargetButton(type: .system)
    private let sendFill = ComposerAccentCircle()
    private let rail = MediaApprovalRailView()
    private var isExporting = false

    init(session: EditSession, theme: ConversationTheme) {
        self.session = session
        self.theme = theme
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = theme.colors.wallpaper
        navigationController?.navigationBar.tintColor = theme.colors.headerTitle
        let close = UIBarButtonItem(
            image: UIImage(
                systemName: "xmark",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: theme.layout.headerIcon, weight: .ultraLight)
            ),
            style: .plain,
            target: self,
            action: #selector(closeTapped)
        )
        close.accessibilityLabel = String(localized: "Close")
        navigationItem.leftBarButtonItem = close

        preview.contentMode = .scaleAspectFit
        preview.clipsToBounds = true
        playerView.isHidden = true
        trimSlider.isHidden = true
        trimSlider.onChange = { [weak self] start, end in
            guard var item = self?.session.selectedItem else { return }
            item.trim = MediaVideoTrim(start: start, end: end)
            self?.session.replaceSelected(item)
        }

        makeTool(title: String(localized: "Crop"), symbol: "crop", action: #selector(openCrop))
        makeTool(title: String(localized: "Draw"), symbol: "pencil.tip", action: #selector(openDraw))
        makeTool(title: String(localized: "Text"), symbol: "textformat", action: #selector(openText))
        toolbar.axis = .horizontal
        toolbar.distribution = .fillEqually
        toolbar.alignment = .center

        captionFill.backgroundColor = theme.colors.composerFill
        captionFill.layer.cornerRadius = theme.radii.composerPill
        captionFill.layer.cornerCurve = .continuous
        captionFill.layer.masksToBounds = true
        captionFill.layer.borderWidth = 0
        captionField.font = theme.fonts.body
        captionField.textColor = theme.colors.incomingPrimaryText
        captionField.tintColor = theme.colors.accent
        captionField.placeholder = String(localized: "Add a caption")
        captionField.delegate = self
        captionField.addTarget(self, action: #selector(captionChanged), for: .editingChanged)
        captionField.borderStyle = .none
        captionField.backgroundColor = .clear

        sendFill.backgroundColor = theme.colors.sendFill
        sendButton.setImage(UIImage.bimbelComposerLine("paperplane.fill"), for: .normal)
        sendButton.tintColor = theme.colors.sendIcon
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        sendButton.accessibilityLabel = String(localized: "Send")

        rail.theme = theme
        rail.onSelect = { [weak self] index in
            self?.session.selectedIndex = index
            self?.refresh()
        }
        rail.onRemove = { [weak self] id in
            self?.session.remove(id: id)
            if self?.session.items.isEmpty == true {
                self?.closeTapped()
            } else {
                self?.refresh()
            }
        }
        rail.onAdd = { [weak self] in
            guard let self else { return }
            if self.session.items.count >= self.theme.layout.maxAttachmentsPerSend {
                BimbelToast.show(
                    EditSession.overLimitMessage(limit: self.theme.layout.maxAttachmentsPerSend),
                    in: self.view,
                    theme: self.theme
                )
                return
            }
            self.onAddMore?(self)
        }

        let captionHost = UIView()
        captionHost.addSubview(captionFill)
        captionHost.addSubview(captionField)
        captionFill.translatesAutoresizingMaskIntoConstraints = false
        captionField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            captionFill.topAnchor.constraint(equalTo: captionHost.topAnchor),
            captionFill.leadingAnchor.constraint(equalTo: captionHost.leadingAnchor),
            captionFill.trailingAnchor.constraint(equalTo: captionHost.trailingAnchor),
            captionFill.bottomAnchor.constraint(equalTo: captionHost.bottomAnchor),
            captionFill.heightAnchor.constraint(equalToConstant: 40),
            captionField.leadingAnchor.constraint(equalTo: captionFill.leadingAnchor, constant: 14),
            captionField.trailingAnchor.constraint(equalTo: captionFill.trailingAnchor, constant: -14),
            captionField.centerYAnchor.constraint(equalTo: captionFill.centerYAnchor)
        ])

        let sendHost = UIView()
        sendHost.addSubview(sendFill)
        sendHost.addSubview(sendButton)
        sendFill.translatesAutoresizingMaskIntoConstraints = false
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            sendFill.centerXAnchor.constraint(equalTo: sendHost.centerXAnchor),
            sendFill.centerYAnchor.constraint(equalTo: sendHost.centerYAnchor),
            sendFill.widthAnchor.constraint(equalToConstant: 40),
            sendFill.heightAnchor.constraint(equalToConstant: 40),
            sendHost.widthAnchor.constraint(equalToConstant: 44),
            sendHost.heightAnchor.constraint(equalToConstant: 44),
            sendButton.centerXAnchor.constraint(equalTo: sendFill.centerXAnchor),
            sendButton.centerYAnchor.constraint(equalTo: sendFill.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 44),
            sendButton.heightAnchor.constraint(equalToConstant: 44)
        ])

        let captionRow = UIStackView(arrangedSubviews: [captionHost, sendHost])
        captionRow.axis = .horizontal
        captionRow.alignment = .center
        captionRow.spacing = 10

        [preview, playerView, trimSlider, toolbar, captionRow, rail].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        NSLayoutConstraint.activate([
            preview.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            preview.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            preview.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playerView.topAnchor.constraint(equalTo: preview.topAnchor),
            playerView.leadingAnchor.constraint(equalTo: preview.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: preview.trailingAnchor),
            playerView.bottomAnchor.constraint(equalTo: preview.bottomAnchor),
            trimSlider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            trimSlider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            trimSlider.bottomAnchor.constraint(equalTo: toolbar.topAnchor, constant: -8),
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            toolbar.heightAnchor.constraint(equalToConstant: theme.layout.hitTarget),
            toolbar.bottomAnchor.constraint(equalTo: captionRow.topAnchor, constant: -10),
            captionRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            captionRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            captionRow.bottomAnchor.constraint(equalTo: rail.topAnchor, constant: -10),
            rail.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            rail.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            rail.heightAnchor.constraint(equalToConstant: theme.layout.approvalThumb + 8),
            rail.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -12),
            preview.bottomAnchor.constraint(equalTo: trimSlider.topAnchor, constant: -8)
        ])
        trimHeight = trimSlider.heightAnchor.constraint(equalToConstant: 36)
        trimHeight.isActive = true

        captionField.text = session.caption
        refresh()
    }

    func admit(_ incoming: [EditSession.Item]) -> Int {
        let result = session.admit(incoming, limit: theme.layout.maxAttachmentsPerSend)
        if result.rejected > 0 {
            BimbelToast.show(
                EditSession.overLimitMessage(limit: theme.layout.maxAttachmentsPerSend),
                in: view,
                theme: theme
            )
        }
        if result.admitted > 0 {
            session.selectedIndex = session.items.count - 1
        }
        refresh()
        return result.rejected
    }

    func mediaEditor(_ editor: UIViewController, didFinish item: EditSession.Item) {
        session.replaceSelected(item)
        refresh()
    }

    private func refresh() {
        title = session.title()
        rail.apply(session: session, theme: theme)
        let video = session.selectedItem?.isVideo == true
        toolbar.alpha = video ? 0.4 : 1
        toolbar.isUserInteractionEnabled = !video
        trimSlider.isHidden = !video
        trimHeight.constant = video ? 36 : 0
        preview.isHidden = video
        playerView.isHidden = !video
        if let item = session.selectedItem {
            if item.isVideo, let url = item.videoURL {
                playerView.play(url: url)
                let duration = item.duration ?? MediaRender.duration(for: url)
                trimSlider.apply(
                    start: item.trim?.start ?? 0,
                    end: item.trim?.end ?? duration,
                    duration: duration,
                    theme: theme
                )
            } else {
                playerView.pause()
                preview.image = MediaRender.composite(item, theme: theme)
            }
        }
        updateSendEnabled()
    }

    private func updateSendEnabled() {
        let ready = !session.items.isEmpty && !isExporting
        sendButton.isEnabled = ready
        sendButton.alpha = ready ? 1 : 0.4
        sendFill.alpha = ready ? 1 : 0.4
    }

    private func makeTool(title: String, symbol: String, action: Selector) {
        let button = HitTargetButton(type: .system)
        button.minimumHitSize = CGSize(width: theme.layout.hitTarget, height: theme.layout.hitTarget)
        var config = UIButton.Configuration.plain()
        config.image = UIImage.bimbelComposerLine(symbol)
        config.preferredSymbolConfigurationForImage = .bimbelComposerLine
        config.title = title
        config.imagePlacement = .top
        config.imagePadding = 4
        config.baseForegroundColor = theme.colors.headerTitle
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: 12, weight: .medium)
            return outgoing
        }
        button.configuration = config
        button.addTarget(self, action: action, for: .touchUpInside)
        toolbar.addArrangedSubview(button)
    }

    private func pushEditor(_ editor: UIViewController) {
        guard session.selectedItem?.isVideo != true else { return }
        (editor as? MediaCropEditorViewController)?.delegate = self
        (editor as? MediaDrawEditorViewController)?.delegate = self
        (editor as? MediaTextEditorViewController)?.delegate = self
        navigationController?.pushViewController(editor, animated: true)
    }

    @objc private func openCrop() {
        guard let item = session.selectedItem else { return }
        pushEditor(MediaCropEditorViewController(item: item, theme: theme))
    }

    @objc private func openDraw() {
        guard let item = session.selectedItem else { return }
        pushEditor(MediaDrawEditorViewController(item: item, theme: theme))
    }

    @objc private func openText() {
        guard let item = session.selectedItem else { return }
        pushEditor(MediaTextEditorViewController(item: item, theme: theme))
    }

    @objc private func captionChanged() {
        session.caption = captionField.text ?? ""
    }

    @objc private func sendTapped() {
        guard !session.items.isEmpty, !isExporting else { return }
        isExporting = true
        updateSendEnabled()
        session.caption = captionField.text ?? ""
        onSend?(session)
    }

    @objc private func closeTapped() {
        playerView.pause()
        onCancel?()
        dismiss(animated: true)
    }
}

final class MediaApprovalRailView: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    var onSelect: ((Int) -> Void)?
    var onRemove: ((String) -> Void)?
    var onAdd: (() -> Void)?
    var theme = ConversationTheme.default

    private var items: [EditSession.Item] = []
    private var selectedIndex = 0
    private let collection: UICollectionView

    override init(frame: CGRect) {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: frame)
        collection.backgroundColor = .clear
        collection.showsHorizontalScrollIndicator = false
        collection.dataSource = self
        collection.delegate = self
        collection.register(RailThumbCell.self, forCellWithReuseIdentifier: RailThumbCell.reuseID)
        collection.register(RailAddCell.self, forCellWithReuseIdentifier: RailAddCell.reuseID)
        addSubview(collection)
        collection.bimbelPinToEdges(of: self, insets: UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func apply(session: EditSession, theme: ConversationTheme) {
        self.theme = theme
        items = session.items
        selectedIndex = session.selectedIndex
        if let layout = collection.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.minimumInteritemSpacing = theme.layout.approvalThumbGap
            layout.minimumLineSpacing = theme.layout.approvalThumbGap
        }
        collection.reloadData()
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count + 1
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.item == items.count {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: RailAddCell.reuseID, for: indexPath) as! RailAddCell
            cell.apply(theme: theme)
            return cell
        }
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: RailThumbCell.reuseID, for: indexPath) as! RailThumbCell
        let item = items[indexPath.item]
        cell.apply(
            image: MediaRender.image(for: item),
            selected: indexPath.item == selectedIndex,
            isVideo: item.isVideo,
            theme: theme
        )
        cell.onRemove = { [weak self] in self?.onRemove?(item.id) }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.item == items.count {
            onAdd?()
        } else {
            onSelect?(indexPath.item)
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let side = theme.layout.approvalThumb
        return CGSize(width: side, height: side)
    }
}

private final class RailThumbCell: UICollectionViewCell {
    static let reuseID = "RailThumbCell"
    var onRemove: (() -> Void)?
    private let imageView = UIImageView()
    private let play = UIImageView(image: UIImage.bimbelComposerLine("play"))
    private let remove = HitTargetButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        contentView.addSubview(imageView)
        imageView.bimbelPinToEdges(of: contentView)
        play.tintColor = .white
        play.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(play)
        remove.setImage(UIImage.bimbelComposerLine("xmark"), for: .normal)
        remove.tintColor = .white
        remove.addTarget(self, action: #selector(tapRemove), for: .touchUpInside)
        remove.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(remove)
        NSLayoutConstraint.activate([
            play.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            play.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            remove.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 2),
            remove.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2),
            remove.widthAnchor.constraint(equalToConstant: 22),
            remove.heightAnchor.constraint(equalToConstant: 22)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func apply(image: UIImage?, selected: Bool, isVideo: Bool, theme: ConversationTheme) {
        imageView.image = image
        imageView.layer.cornerRadius = theme.radii.approvalThumb
        play.isHidden = !isVideo
        remove.isHidden = !selected
        contentView.layer.borderWidth = selected ? 2 : 0
        contentView.layer.borderColor = theme.colors.accent.cgColor
        contentView.layer.cornerRadius = theme.radii.approvalThumb
        contentView.clipsToBounds = true
    }

    @objc private func tapRemove() { onRemove?() }
}

private final class RailAddCell: UICollectionViewCell {
    static let reuseID = "RailAddCell"
    private let plus = UIImageView()
    private let dash = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        plus.image = UIImage.bimbelComposerLine("plus")
        plus.contentMode = .center
        contentView.addSubview(plus)
        plus.bimbelPinToEdges(of: contentView)
        dash.strokeColor = UIColor.tertiaryLabel.cgColor
        dash.fillColor = UIColor.clear.cgColor
        dash.lineDashPattern = [5, 4]
        dash.lineWidth = 1.5
        contentView.layer.addSublayer(dash)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func apply(theme: ConversationTheme) {
        plus.tintColor = theme.colors.composerIcon
        plus.image = UIImage.bimbelComposerLine("plus")
        contentView.layer.cornerRadius = theme.radii.approvalThumb
        dash.strokeColor = theme.colors.composerIcon.cgColor
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let radius = contentView.layer.cornerRadius
        dash.path = UIBezierPath(roundedRect: contentView.bounds.insetBy(dx: 1, dy: 1), cornerRadius: radius).cgPath
        dash.frame = contentView.bounds
    }
}

final class ApprovalPlayerView: UIView {
    private var player: AVPlayer?
    private var layerPlayer: AVPlayerLayer { layer as! AVPlayerLayer }
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    func play(url: URL) {
        if let current = (player?.currentItem?.asset as? AVURLAsset)?.url, current == url {
            player?.play()
            return
        }
        let next = AVPlayer(url: url)
        player = next
        layerPlayer.player = next
        layerPlayer.videoGravity = .resizeAspect
        next.play()
    }

    func pause() { player?.pause() }
}

final class VideoTrimControl: UIView {
    var onChange: ((TimeInterval, TimeInterval) -> Void)?
    private let start = UISlider()
    private let end = UISlider()
    private var duration: TimeInterval = 1

    override init(frame: CGRect) {
        super.init(frame: frame)
        start.addTarget(self, action: #selector(changed), for: .valueChanged)
        end.addTarget(self, action: #selector(changed), for: .valueChanged)
        let stack = UIStackView(arrangedSubviews: [start, end])
        stack.axis = .vertical
        stack.spacing = 2
        addSubview(stack)
        stack.bimbelPinToEdges(of: self)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func apply(start: TimeInterval, end: TimeInterval, duration: TimeInterval, theme: ConversationTheme) {
        self.duration = max(duration, 0.1)
        self.start.minimumValue = 0
        self.start.maximumValue = Float(self.duration)
        self.end.minimumValue = 0
        self.end.maximumValue = Float(self.duration)
        self.start.value = Float(start)
        self.end.value = Float(end)
        self.start.minimumTrackTintColor = theme.colors.accent
        self.end.minimumTrackTintColor = theme.colors.accent
    }

    @objc private func changed() {
        if start.value > end.value - 0.1 {
            start.value = end.value - 0.1
        }
        if end.value < start.value + 0.1 {
            end.value = start.value + 0.1
        }
        onChange?(TimeInterval(start.value), TimeInterval(end.value))
    }
}
