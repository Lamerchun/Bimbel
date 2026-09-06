import UIKit

@MainActor
protocol MediaEditorDelegate: AnyObject {
    func mediaEditor(_ editor: UIViewController, didFinish item: EditSession.Item)
}

final class MediaCropEditorViewController: UIViewController, UIScrollViewDelegate {
    weak var delegate: MediaEditorDelegate?
    private var item: EditSession.Item
    private let theme: ConversationTheme
    private let scroll = UIScrollView()
    private let imageView = UIImageView()
    private var working: UIImage

    init(item: EditSession.Item, theme: ConversationTheme) {
        self.item = item
        self.theme = theme
        self.working = MediaRender.composite(item, theme: theme) ?? UIImage()
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        title = String(localized: "Crop")
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(
                title: String(localized: "Done"),
                style: .done,
                target: self,
                action: #selector(done)
            ),
            UIBarButtonItem(
                image: UIImage.bimbelComposerLine("rotate.right"),
                style: .plain,
                target: self,
                action: #selector(rotate)
            )
        ]

        scroll.delegate = self
        scroll.minimumZoomScale = 1
        scroll.maximumZoomScale = 4
        scroll.showsHorizontalScrollIndicator = false
        scroll.showsVerticalScrollIndicator = false
        scroll.bouncesZoom = true
        imageView.image = working
        imageView.contentMode = .scaleAspectFit
        scroll.addSubview(imageView)
        view.addSubview(scroll)
        scroll.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutImage()
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

    private func layoutImage() {
        guard let image = imageView.image, scroll.bounds.width > 0 else { return }
        let bounds = scroll.bounds.size
        let scale = min(bounds.width / max(image.size.width, 1), bounds.height / max(image.size.height, 1))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        imageView.frame = CGRect(origin: .zero, size: size)
        scroll.contentSize = size
        let insetX = max(0, (bounds.width - size.width) / 2)
        let insetY = max(0, (bounds.height - size.height) / 2)
        scroll.contentInset = UIEdgeInsets(top: insetY, left: insetX, bottom: insetY, right: insetX)
    }

    @objc private func rotate() {
        working = MediaRender.apply(
            crop: MediaCrop(normalizedRect: CGRect(x: 0, y: 0, width: 1, height: 1), rotationQuarterTurns: 1),
            to: working
        )
        imageView.image = working
        scroll.zoomScale = 1
        layoutImage()
    }

    @objc private func done() {
        guard let image = imageView.image else { return }
        let visible = scroll.convert(scroll.bounds, to: imageView)
        let width = max(imageView.bounds.width, 1)
        let height = max(imageView.bounds.height, 1)
        let normalized = CGRect(
            x: max(0, visible.minX / width),
            y: max(0, visible.minY / height),
            width: min(1, visible.width / width),
            height: min(1, visible.height / height)
        )
        let cropped = MediaRender.apply(crop: MediaCrop(normalizedRect: normalized), to: image)
        guard let data = MediaRender.jpegData(from: cropped) else { return }
        var next = item
        next.original = .data(data)
        next.crop = .identity
        next.strokes = []
        next.texts = []
        next.pixelWidth = Int(cropped.size.width * cropped.scale)
        next.pixelHeight = Int(cropped.size.height * cropped.scale)
        delegate?.mediaEditor(self, didFinish: next)
        navigationController?.popViewController(animated: true)
    }
}

final class MediaDrawEditorViewController: UIViewController {
    weak var delegate: MediaEditorDelegate?
    private var item: EditSession.Item
    private let theme: ConversationTheme
    private let imageView = UIImageView()
    private let canvas = DrawCanvas()

    init(item: EditSession.Item, theme: ConversationTheme) {
        self.item = item
        self.theme = theme
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        title = String(localized: "Draw")
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(
                title: String(localized: "Done"),
                style: .done,
                target: self,
                action: #selector(done)
            ),
            UIBarButtonItem(
                title: String(localized: "Undo"),
                style: .plain,
                target: self,
                action: #selector(undo)
            )
        ]
        imageView.image = MediaRender.composite(item, theme: theme)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        canvas.strokeColor = theme.colors.accent
        canvas.strokeWidth = ConversationApprovalChrome.drawWidth
        canvas.translatesAutoresizingMaskIntoConstraints = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)
        imageView.addSubview(canvas)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            canvas.topAnchor.constraint(equalTo: imageView.topAnchor),
            canvas.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            canvas.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
            canvas.bottomAnchor.constraint(equalTo: imageView.bottomAnchor)
        ])
    }

    @objc private func undo() { canvas.undo() }

    @objc private func done() {
        guard let image = imageView.image else { return }
        let fitted = aspectFitRect(image.size, in: imageView.bounds.size)
        var strokes = item.strokes
        strokes.append(contentsOf: canvas.normalizedStrokes(in: fitted))
        var next = item
        let painted = MediaRender.paint(strokes: strokes, texts: [], on: image, theme: theme)
        if let data = MediaRender.jpegData(from: painted) {
            next.original = .data(data)
            next.strokes = []
            next.texts = item.texts
            next.crop = .identity
            next.pixelWidth = Int(painted.size.width * painted.scale)
            next.pixelHeight = Int(painted.size.height * painted.scale)
        } else {
            next.strokes = strokes
        }
        delegate?.mediaEditor(self, didFinish: next)
        navigationController?.popViewController(animated: true)
    }
}

final class MediaTextEditorViewController: UIViewController, UITextFieldDelegate {
    weak var delegate: MediaEditorDelegate?
    private var item: EditSession.Item
    private let theme: ConversationTheme
    private let imageView = UIImageView()
    private let field = UITextField()
    private var center = CGPoint(x: 0.5, y: 0.5)

    init(item: EditSession.Item, theme: ConversationTheme) {
        self.item = item
        self.theme = theme
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        title = String(localized: "Text")
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: String(localized: "Done"),
            style: .done,
            target: self,
            action: #selector(done)
        )
        imageView.image = MediaRender.composite(item, theme: theme)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])

        field.font = theme.fonts.bubbleBody
        field.textColor = ConversationApprovalChrome.textColor
        field.backgroundColor = .clear
        field.layer.cornerRadius = 0
        field.layer.masksToBounds = false
        field.textAlignment = .center
        field.delegate = self
        field.attributedPlaceholder = NSAttributedString(
            string: String(localized: "Text"),
            attributes: [.foregroundColor: UIColor.tertiaryLabel, .font: theme.fonts.bubbleBody]
        )
        let pad = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        field.leftView = pad
        field.leftViewMode = .always
        field.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        field.rightViewMode = .always
        field.translatesAutoresizingMaskIntoConstraints = false
        imageView.addSubview(field)
        NSLayoutConstraint.activate([
            field.centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
            field.centerYAnchor.constraint(equalTo: imageView.centerYAnchor),
            field.widthAnchor.constraint(lessThanOrEqualTo: imageView.widthAnchor, constant: -32),
            field.heightAnchor.constraint(greaterThanOrEqualToConstant: 36)
        ])
        let scrim = UIView()
        scrim.backgroundColor = ConversationApprovalChrome.textScrim
        scrim.layer.cornerRadius = 8
        scrim.isUserInteractionEnabled = false
        imageView.insertSubview(scrim, belowSubview: field)
        scrim.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrim.topAnchor.constraint(equalTo: field.topAnchor, constant: -4),
            scrim.leadingAnchor.constraint(equalTo: field.leadingAnchor, constant: -4),
            scrim.trailingAnchor.constraint(equalTo: field.trailingAnchor, constant: 4),
            scrim.bottomAnchor.constraint(equalTo: field.bottomAnchor, constant: 4)
        ])
        let pan = UIPanGestureRecognizer(target: self, action: #selector(drag(_:)))
        field.addGestureRecognizer(pan)
        field.becomeFirstResponder()
    }

    @objc private func drag(_ gesture: UIPanGestureRecognizer) {
        let point = gesture.location(in: imageView)
        field.center = point
        center = CGPoint(
            x: point.x / max(imageView.bounds.width, 1),
            y: point.y / max(imageView.bounds.height, 1)
        )
    }

    @objc private func done() {
        let text = field.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var next = item
        if !text.isEmpty {
            next.texts.append(MediaTextOverlay(text: text, normalizedCenter: center))
        }
        if let painted = MediaRender.composite(next, theme: theme), let data = MediaRender.jpegData(from: painted) {
            next.original = .data(data)
            next.strokes = []
            next.texts = []
            next.crop = .identity
            next.pixelWidth = Int(painted.size.width * painted.scale)
            next.pixelHeight = Int(painted.size.height * painted.scale)
        }
        delegate?.mediaEditor(self, didFinish: next)
        navigationController?.popViewController(animated: true)
    }
}

final class DrawCanvas: UIView {
    var strokeColor: UIColor = .systemGreen
    var strokeWidth: CGFloat = 4
    private var strokes: [[CGPoint]] = []
    private var current: [CGPoint] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleDraw(_:)))
        addGestureRecognizer(pan)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func undo() {
        if !current.isEmpty { current = [] }
        else if !strokes.isEmpty { strokes.removeLast() }
        setNeedsDisplay()
    }

    func normalizedStrokes(in fitted: CGRect) -> [MediaStroke] {
        let all = strokes + (current.count > 1 ? [current] : [])
        return all.map { points in
            MediaStroke(
                points: points.map { point in
                    CGPoint(
                        x: (point.x - fitted.minX) / max(fitted.width, 1),
                        y: (point.y - fitted.minY) / max(fitted.height, 1)
                    )
                },
                width: ConversationApprovalChrome.drawWidth
            )
        }
    }

    @objc private func handleDraw(_ gesture: UIPanGestureRecognizer) {
        let point = gesture.location(in: self)
        switch gesture.state {
        case .began:
            current = [point]
        case .changed:
            current.append(point)
            setNeedsDisplay()
        case .ended, .cancelled:
            if current.count > 1 { strokes.append(current) }
            current = []
            setNeedsDisplay()
        default:
            break
        }
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.setStrokeColor(strokeColor.cgColor)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setLineWidth(strokeWidth)
        for stroke in strokes + [current] where stroke.count > 1 {
            context.beginPath()
            context.move(to: stroke[0])
            for point in stroke.dropFirst() { context.addLine(to: point) }
            context.strokePath()
        }
    }
}

func aspectFitRect(_ image: CGSize, in bounds: CGSize) -> CGRect {
    let scale = min(bounds.width / max(image.width, 1), bounds.height / max(image.height, 1))
    let size = CGSize(width: image.width * scale, height: image.height * scale)
    return CGRect(
        x: (bounds.width - size.width) / 2,
        y: (bounds.height - size.height) / 2,
        width: size.width,
        height: size.height
    )
}
