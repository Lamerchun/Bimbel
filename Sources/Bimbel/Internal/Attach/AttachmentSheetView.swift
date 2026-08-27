import Photos
import UIKit

final class AttachmentSheetView: UIInputView {
    var onAction: ((AttachmentAction) -> Void)?
    var onPickAsset: ((PHAsset) -> Void)?

    private let grabber = UIView()
    private let grid = UIStackView()
    private let recents = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
    private var assets: [PHAsset] = []
    private var theme = ConversationTheme.default
    private let gated: Set<AttachmentAction> = [.poll, .event, .aiImages]

    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 360), inputViewStyle: .keyboard)
        allowsSelfSizing = true
        backgroundColor = .clear
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 360)
    }

    private func setup() {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)
        card.bimbelPinToEdges(of: self)
        card.backgroundColor = UIColor.secondarySystemBackground
        card.layer.cornerRadius = 28
        card.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        card.layer.masksToBounds = true

        grabber.backgroundColor = UIColor.tertiaryLabel
        grabber.layer.cornerRadius = 2.5
        grabber.translatesAutoresizingMaskIntoConstraints = false

        grid.axis = .vertical
        grid.spacing = 16
        grid.distribution = .fillEqually
        let actions: [[AttachmentAction]] = [
            [.photos, .camera, .location, .contact],
            [.document, .poll, .event, .aiImages]
        ]
        for rowActions in actions {
            let row = UIStackView()
            row.axis = .horizontal
            row.distribution = .fillEqually
            row.spacing = 8
            for action in rowActions {
                row.addArrangedSubview(makeAction(action))
            }
            grid.addArrangedSubview(row)
        }
        grid.translatesAutoresizingMaskIntoConstraints = false

        let layout = recents.collectionViewLayout as? UICollectionViewFlowLayout
        layout?.minimumInteritemSpacing = 4
        layout?.minimumLineSpacing = 4
        recents.backgroundColor = .clear
        recents.dataSource = self
        recents.delegate = self
        recents.register(RecentCell.self, forCellWithReuseIdentifier: RecentCell.reuseID)
        recents.translatesAutoresizingMaskIntoConstraints = false

        let recentsLabel = UILabel()
        recentsLabel.text = "Recents"
        recentsLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        recentsLabel.textColor = .secondaryLabel
        recentsLabel.translatesAutoresizingMaskIntoConstraints = false

        [grabber, grid, recentsLabel, recents].forEach { card.addSubview($0) }
        NSLayoutConstraint.activate([
            grabber.topAnchor.constraint(equalTo: card.topAnchor, constant: 8),
            grabber.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            grabber.widthAnchor.constraint(equalToConstant: 36),
            grabber.heightAnchor.constraint(equalToConstant: 5),
            grid.topAnchor.constraint(equalTo: grabber.bottomAnchor, constant: 16),
            grid.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            grid.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            grid.heightAnchor.constraint(equalToConstant: 168),
            recentsLabel.topAnchor.constraint(equalTo: grid.bottomAnchor, constant: 12),
            recentsLabel.leadingAnchor.constraint(equalTo: grid.leadingAnchor),
            recents.topAnchor.constraint(equalTo: recentsLabel.bottomAnchor, constant: 8),
            recents.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            recents.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            recents.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -8)
        ])
    }

    func apply(theme: ConversationTheme) {
        self.theme = theme
        backgroundColor = .clear
    }

    func reloadRecents() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            assets = []
            recents.reloadData()
            return
        }
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 24
        let result = PHAsset.fetchAssets(with: .image, options: options)
        var fetched: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in fetched.append(asset) }
        assets = fetched
        recents.reloadData()
    }

    private func makeAction(_ action: AttachmentAction) -> UIView {
        let button = HitTargetButton(type: .system)
        button.tag = action.tag
        button.addTarget(self, action: #selector(tapAction(_:)), for: .touchUpInside)
        let disabled = gated.contains(action)
        button.isEnabled = !disabled
        button.alpha = disabled ? 0.45 : 1
        button.accessibilityLabel = action.title
        if disabled {
            button.accessibilityHint = "Unavailable in this version"
        }

        let circle = UIView()
        circle.translatesAutoresizingMaskIntoConstraints = false
        circle.backgroundColor = action.color
        circle.layer.cornerRadius = 28
        let icon = UIImageView(image: UIImage(systemName: action.symbol))
        icon.tintColor = .white
        icon.translatesAutoresizingMaskIntoConstraints = false
        circle.addSubview(icon)

        let label = UILabel()
        label.text = action.title
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textAlignment = .center
        label.textColor = .label

        let stack = UIStackView(arrangedSubviews: [circle, label])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 6
        stack.isUserInteractionEnabled = false

        button.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            circle.widthAnchor.constraint(equalToConstant: 56),
            circle.heightAnchor.constraint(equalToConstant: 56),
            icon.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: circle.centerYAnchor),
            stack.topAnchor.constraint(equalTo: button.topAnchor),
            stack.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        return button
    }

    @objc private func tapAction(_ sender: UIButton) {
        guard let action = AttachmentAction.from(tag: sender.tag), !gated.contains(action) else { return }
        onAction?(action)
    }
}

extension AttachmentSheetView: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        assets.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: RecentCell.reuseID, for: indexPath) as! RecentCell
        cell.configure(asset: assets[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        onPickAsset?(assets[indexPath.item])
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let spacing: CGFloat = 12
        let width = floor((collectionView.bounds.width - spacing) / 4)
        return CGSize(width: width, height: width)
    }
}

private final class RecentCell: UICollectionViewCell {
    static let reuseID = "RecentCell"
    private let imageView = UIImageView()
    private var request: PHImageRequestID?

    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 6
        contentView.addSubview(imageView)
        imageView.bimbelPinToEdges(of: contentView)
        imageView.backgroundColor = UIColor.tertiarySystemFill
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(asset: PHAsset) {
        if let request { PHImageManager.default().cancelImageRequest(request) }
        request = PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 200, height: 200),
            contentMode: .aspectFill,
            options: nil
        ) { [weak self] image, _ in
            self?.imageView.image = image
        }
    }
}

private extension AttachmentAction {
    var title: String {
        switch self {
        case .photos: return "Photos"
        case .camera: return "Camera"
        case .location: return "Location"
        case .contact: return "Contact"
        case .document: return "Document"
        case .poll: return "Poll"
        case .event: return "Event"
        case .aiImages: return "AI images"
        }
    }

    var symbol: String {
        switch self {
        case .photos: return "photo"
        case .camera: return "camera.fill"
        case .location: return "location.fill"
        case .contact: return "person.crop.circle"
        case .document: return "doc.fill"
        case .poll: return "chart.bar.fill"
        case .event: return "calendar"
        case .aiImages: return "sparkles"
        }
    }

    var color: UIColor {
        switch self {
        case .photos: return UIColor.systemBlue
        case .camera: return UIColor.darkGray
        case .location: return UIColor.systemGreen
        case .contact: return UIColor.systemGray
        case .document: return UIColor.systemBlue
        case .poll: return UIColor.systemOrange
        case .event: return UIColor.systemRed
        case .aiImages: return UIColor.systemBlue
        }
    }

    var tag: Int {
        switch self {
        case .photos: return 1
        case .camera: return 2
        case .location: return 3
        case .contact: return 4
        case .document: return 5
        case .poll: return 6
        case .event: return 7
        case .aiImages: return 8
        }
    }

    static func from(tag: Int) -> AttachmentAction? {
        switch tag {
        case 1: return .photos
        case 2: return .camera
        case 3: return .location
        case 4: return .contact
        case 5: return .document
        case 6: return .poll
        case 7: return .event
        case 8: return .aiImages
        default: return nil
        }
    }
}
