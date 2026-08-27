import UIKit

/// Single owner of conversation **list** insets.
///
/// The composer is not positioned here. When the keyboard is visible it lives in
/// the view controller's `inputAccessoryView` (keyboard window). When hidden it
/// is docked in the conversation VC at the safe-area bottom.
///
/// Insets come from `keyboardLayoutGuide` / keyboard frame notifications while
/// the composer is in the accessory (that frame already includes the accessory —
/// do not add composer height on top). While docked, the inset is the composer
/// height plus the home-indicator safe area.
///
/// `flushingLayout` may only be true outside collection view callbacks. Forcing a
/// layout pass from `scrollViewDidScroll` or `viewDidLayoutSubviews` runs while
/// the list is still dequeuing cells, which trips UIKit's "dequeued view was not
/// returned" assertion.
@MainActor
final class ComposerKeyboardTracker {
    private weak var host: UIView?
    private weak var composer: UIView?
    private weak var collectionView: UICollectionView?
    private var lastInset: CGFloat = -1
    private var lastKeyboardFrameInScreen: CGRect?
    private var observers: [NSObjectProtocol] = []

    var isComposerInAccessory = false
    var bottomBreathingRoom: CGFloat = 8
    var dismissPanEnabled = true {
        didSet { applyDismissMode() }
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    func attach(host: UIView, composer: UIView, collectionView: UICollectionView) {
        self.host = host
        self.composer = composer
        self.collectionView = collectionView
        applyDismissMode()
        observeKeyboard()
        syncListInsets(flushingLayout: true)
    }

    func applyDismissMode() {
        collectionView?.keyboardDismissMode = dismissPanEnabled ? .interactiveWithAccessory : .none
    }

    func syncListInsets(flushingLayout: Bool = false) {
        guard let host, let collectionView else { return }
        if flushingLayout {
            host.layoutIfNeeded()
        }
        let overlap = Self.overlap(
            isComposerInAccessory: isComposerInAccessory,
            keyboardTop: keyboardTop(in: collectionView, host: host),
            collectionMaxY: collectionView.bounds.maxY,
            dockedComposerHeight: dockedComposerHeight(),
            safeAreaBottom: host.safeAreaInsets.bottom,
            breathing: bottomBreathingRoom
        )
        guard abs(overlap - lastInset) > 0.5 else { return }
        lastInset = overlap
        var inset = collectionView.contentInset
        inset.bottom = overlap
        collectionView.contentInset = inset
        collectionView.verticalScrollIndicatorInsets.bottom = overlap
        collectionView.scrollIndicatorInsets.bottom = overlap
    }

    /// Pure overlap math so docked vs accessory insets can be tested without UIKit layout.
    static func overlap(
        isComposerInAccessory: Bool,
        keyboardTop: CGFloat,
        collectionMaxY: CGFloat,
        dockedComposerHeight: CGFloat,
        safeAreaBottom: CGFloat,
        breathing: CGFloat
    ) -> CGFloat {
        let base: CGFloat
        if isComposerInAccessory {
            base = max(0, collectionMaxY - keyboardTop)
        } else {
            let height = dockedComposerHeight > 1 ? dockedComposerHeight : 58
            base = height + safeAreaBottom
        }
        return base + breathing
    }

    private func dockedComposerHeight() -> CGFloat {
        composer?.bounds.height ?? 0
    }

    private func keyboardTop(in collectionView: UICollectionView, host: UIView) -> CGFloat {
        let guide = host.keyboardLayoutGuide.layoutFrame
        var top = collectionView.convert(CGPoint(x: 0, y: guide.minY), from: host).y
        if let screen = lastKeyboardFrameInScreen {
            let inCollection = collectionView.convert(screen, from: nil)
            top = min(top, inCollection.minY)
        }
        return top
    }

    private func observeKeyboard() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers = []
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                self?.captureFrame(notification)
                self?.syncListInsets(flushingLayout: true)
            }
        })
        observers.append(center.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                self?.captureFrame(notification)
                self?.syncListInsets(flushingLayout: true)
            }
        })
        observers.append(center.addObserver(
            forName: UIResponder.keyboardWillChangeFrameNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                self?.captureFrame(notification)
                // Interactive dismiss can run during `scrollViewDidScroll`. Do not flush.
                self?.syncListInsets()
            }
        })
        observers.append(center.addObserver(
            forName: UIResponder.keyboardDidChangeFrameNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                self?.captureFrame(notification)
                self?.syncListInsets()
            }
        })
    }

    private func captureFrame(_ notification: Notification) {
        lastKeyboardFrameInScreen = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
    }
}
