import UIKit

final class MediaPagerViewController: UIViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate, UIGestureRecognizerDelegate {
    private let items: [Message]
    private let theme: ConversationTheme
    private let onSave: (Message) -> Void
    private let onForward: (Message) -> Void

    private let dimmer = UIView()
    private let pages: UIPageViewController
    private let chrome: MediaPagerChromeView
    private var index: Int
    private var currentPage: MediaPageViewController?
    private var dismissStart: CGPoint = .zero
    private var chromeVisible = true

    init(
        items: [Message],
        startID: MessageID,
        theme: ConversationTheme,
        onSave: @escaping (Message) -> Void,
        onForward: @escaping (Message) -> Void
    ) {
        self.items = items
        self.theme = theme
        self.onSave = onSave
        self.onForward = onForward
        self.index = MediaPagerItems.startIndex(in: items, id: startID)
        self.pages = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal,
            options: [.interPageSpacing: 12 as NSNumber]
        )
        self.chrome = MediaPagerChromeView(theme: theme)
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
        modalPresentationCapturesStatusBarAppearance = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        dimmer.backgroundColor = .black
        dimmer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dimmer)
        dimmer.bimbelPinToEdges(of: view)

        pages.dataSource = items.count > 1 ? self : nil
        pages.delegate = self
        addChild(pages)
        view.addSubview(pages.view)
        pages.view.translatesAutoresizingMaskIntoConstraints = false
        pages.view.bimbelPinToEdges(of: view)
        pages.didMove(toParent: self)

        chrome.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(chrome)
        NSLayoutConstraint.activate([
            chrome.topAnchor.constraint(equalTo: view.topAnchor),
            chrome.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            chrome.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        chrome.onClose = { [weak self] in self?.dismiss(animated: true) }
        chrome.onSave = { [weak self] in
            guard let self, let message = self.currentMessage else { return }
            self.onSave(message)
        }
        chrome.onForward = { [weak self] in
            guard let self, let message = self.currentMessage else { return }
            self.onForward(message)
        }

        if let start = makePage(at: index) {
            currentPage = start
            start.onSingleTap = { [weak self] in self?.toggleChrome() }
            pages.setViewControllers([start], direction: .forward, animated: false)
        }

        let pan = UIPanGestureRecognizer(target: self, action: #selector(dismissPan(_:)))
        pan.delegate = self
        view.addGestureRecognizer(pan)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        chrome.applySafeTop(view.safeAreaInsets.top, theme: theme)
    }

    private var currentMessage: Message? {
        currentPage?.message ?? items[safe: index]
    }

    private func makePage(at index: Int) -> MediaPageViewController? {
        guard items.indices.contains(index) else { return nil }
        let page = MediaPageViewController(message: items[index], theme: theme)
        page.onSingleTap = { [weak self] in self?.toggleChrome() }
        return page
    }

    private func toggleChrome() {
        chromeVisible.toggle()
        UIView.animate(withDuration: 0.2) {
            self.chrome.alpha = self.chromeVisible ? 1 : 0
        }
    }

    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerBefore viewController: UIViewController
    ) -> UIViewController? {
        guard let page = viewController as? MediaPageViewController,
              let current = items.firstIndex(where: { $0.id == page.message.id }),
              current > 0
        else { return nil }
        return makePage(at: current - 1)
    }

    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerAfter viewController: UIViewController
    ) -> UIViewController? {
        guard let page = viewController as? MediaPageViewController,
              let current = items.firstIndex(where: { $0.id == page.message.id }),
              current + 1 < items.count
        else { return nil }
        return makePage(at: current + 1)
    }

    func pageViewController(
        _ pageViewController: UIPageViewController,
        didFinishAnimating finished: Bool,
        previousViewControllers: [UIViewController],
        transitionCompleted completed: Bool
    ) {
        guard completed, let page = pageViewController.viewControllers?.first as? MediaPageViewController else { return }
        (previousViewControllers as? [MediaPageViewController])?.forEach { $0.pauseVideo() }
        currentPage = page
        index = MediaPagerItems.startIndex(in: items, id: page.message.id)
        page.onSingleTap = { [weak self] in self?.toggleChrome() }
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        guard currentPage?.isZoomed != true else { return false }
        let velocity = pan.velocity(in: view)
        return abs(velocity.y) > abs(velocity.x)
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        false
    }

    @objc private func dismissPan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        switch gesture.state {
        case .began:
            dismissStart = translation
            currentPage?.resetZoom()
        case .changed:
            let y = max(0, translation.y)
            pages.view.transform = CGAffineTransform(translationX: 0, y: y)
            let progress = min(1, y / 280)
            dimmer.alpha = 1 - progress * 0.7
            chrome.alpha = chromeVisible ? (1 - progress) : 0
        case .ended, .cancelled, .failed:
            let y = max(0, translation.y)
            let velocity = gesture.velocity(in: view).y
            if y > 140 || velocity > 900 {
                UIView.animate(withDuration: 0.22, animations: {
                    self.pages.view.transform = CGAffineTransform(translationX: 0, y: self.view.bounds.height)
                    self.dimmer.alpha = 0
                    self.chrome.alpha = 0
                }, completion: { _ in
                    self.dismiss(animated: false)
                })
            } else {
                UIView.animate(withDuration: 0.28, delay: 0, usingSpringWithDamping: 0.86, initialSpringVelocity: 0.4) {
                    self.pages.view.transform = .identity
                    self.dimmer.alpha = 1
                    self.chrome.alpha = self.chromeVisible ? 1 : 0
                }
            }
        default:
            break
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
