import AVFoundation
import UIKit

final class MediaPageViewController: UIViewController, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    let message: Message
    var isZoomed: Bool { scroll.zoomScale > 1.01 }
    var onSingleTap: (() -> Void)?

    private let theme: ConversationTheme
    private let scroll = UIScrollView()
    private let imageView = UIImageView()
    private let playBadge = UIImageView(image: UIImage(systemName: "play.circle"))
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var videoURL: URL?

    init(message: Message, theme: ConversationTheme) {
        self.message = message
        self.theme = theme
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        scroll.delegate = self
        scroll.minimumZoomScale = 1
        scroll.maximumZoomScale = 4
        scroll.showsHorizontalScrollIndicator = false
        scroll.showsVerticalScrollIndicator = false
        scroll.bouncesZoom = true
        scroll.contentInsetAdjustmentBehavior = .never
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        view.addSubview(scroll)
        scroll.addSubview(imageView)
        scroll.bimbelPinToEdges(of: view)

        playBadge.tintColor = .white
        playBadge.contentMode = .scaleAspectFit
        playBadge.translatesAutoresizingMaskIntoConstraints = false
        playBadge.isHidden = true
        view.addSubview(playBadge)
        NSLayoutConstraint.activate([
            playBadge.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            playBadge.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            playBadge.widthAnchor.constraint(equalToConstant: theme.layout.hitTarget),
            playBadge.heightAnchor.constraint(equalToConstant: theme.layout.hitTarget)
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
        let double = UITapGestureRecognizer(target: self, action: #selector(doubleTapped))
        double.numberOfTapsRequired = 2
        tap.require(toFail: double)
        view.addGestureRecognizer(tap)
        view.addGestureRecognizer(double)

        loadContent()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutImage()
        playerLayer?.frame = view.bounds
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        pauseVideo()
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerImage()
    }

    func resetZoom() {
        scroll.setZoomScale(1, animated: false)
    }

    func pauseVideo() {
        player?.pause()
        playBadge.isHidden = videoURL == nil
    }

    private func loadContent() {
        switch message.kind {
        case .image(let media):
            imageView.image = ImageLoader.image(from: media.source)
            ImageLoader.load(media.source) { [weak self] image in
                self?.imageView.image = image
                self?.layoutImage()
            }
        case .video(let media):
            imageView.image = ImageLoader.image(from: media.source)
            ImageLoader.load(media.source) { [weak self] image in
                self?.imageView.image = image
                self?.layoutImage()
            }
            videoURL = Self.playableURL(for: media)
            scroll.maximumZoomScale = 1
            if let url = videoURL {
                let player = AVPlayer(url: url)
                let layer = AVPlayerLayer(player: player)
                layer.videoGravity = .resizeAspect
                layer.frame = view.bounds
                view.layer.insertSublayer(layer, above: scroll.layer)
                self.player = player
                self.playerLayer = layer
                playBadge.image = UIImage(
                    systemName: "play.circle",
                    withConfiguration: UIImage.SymbolConfiguration(pointSize: theme.layout.headerIcon, weight: .ultraLight)
                )
                playBadge.isHidden = false
            }
        default:
            break
        }
    }

    private static func playableURL(for media: Media) -> URL? {
        switch media.source {
        case .url(let url):
            return url
        case .data(let data):
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("bimbel-pager-\(UUID().uuidString).mov")
            do {
                try data.write(to: dest)
                return dest
            } catch {
                return nil
            }
        case .asset:
            return nil
        }
    }

    private func layoutImage() {
        guard let image = imageView.image, scroll.bounds.width > 0 else { return }
        let bounds = scroll.bounds.size
        let scale = min(bounds.width / max(image.size.width, 1), bounds.height / max(image.size.height, 1))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        imageView.frame = CGRect(origin: .zero, size: size)
        scroll.contentSize = size
        centerImage()
    }

    private func centerImage() {
        let bounds = scroll.bounds.size
        let insetX = max(0, (bounds.width - scroll.contentSize.width) / 2)
        let insetY = max(0, (bounds.height - scroll.contentSize.height) / 2)
        scroll.contentInset = UIEdgeInsets(top: insetY, left: insetX, bottom: insetY, right: insetX)
    }

    @objc private func tapped() {
        if videoURL != nil {
            toggleVideo()
        }
        onSingleTap?()
    }

    @objc private func doubleTapped(_ gesture: UITapGestureRecognizer) {
        if scroll.zoomScale > 1.01 {
            scroll.setZoomScale(1, animated: true)
        } else {
            let point = gesture.location(in: imageView)
            let zoom: CGFloat = 2.4
            let size = CGSize(width: scroll.bounds.width / zoom, height: scroll.bounds.height / zoom)
            scroll.zoom(
                to: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height),
                animated: true
            )
        }
    }

    private func toggleVideo() {
        guard let player else { return }
        if player.timeControlStatus == .playing {
            player.pause()
            playBadge.isHidden = false
        } else {
            player.play()
            playBadge.isHidden = true
        }
    }
}
