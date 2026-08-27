import UIKit

/// Single owner of conversation **list** insets.
///
/// The composer is not positioned here. When the keyboard is visible it lives in
/// the view controller's `inputAccessoryView` (keyboard window). When hidden it
/// is docked in the conversation VC at the safe-area bottom.
///
/// Insets come from the top of the **composer** (docked or in the accessory)
/// so the last bubble clears the floating bar. The keyboard frame is used as
/// a second covering edge; do not add keyboard height + composer height when
/// the frame already includes the accessory. A self-sizing accessory often
/// sits *above* a keys-only keyboard frame — that case still adds composer
/// height. While docked, the inset is composer height + home-indicator + gap.
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
            composerTopInCollection: composerTopInCollection(),
            dockedComposerHeight: dockedComposerHeight(),
            safeAreaBottom: host.safeAreaInsets.bottom,
            breathing: bottomBreathingRoom
        )
        let padding = Self.layoutBottomPadding(
            composerHeight: dockedComposerHeight(),
            breathing: bottomBreathingRoom
        )
        let insetChanged = abs(overlap - lastInset) > 0.5
        guard insetChanged else {
            if flushingLayout { onApplied?(overlap, padding, true) }
            return
        }
        lastInset = overlap
        var inset = collectionView.contentInset
        inset.bottom = overlap
        collectionView.contentInset = inset
        collectionView.verticalScrollIndicatorInsets.bottom = overlap
        collectionView.scrollIndicatorInsets.bottom = overlap
        onApplied?(overlap, padding, flushingLayout)
    }

    /// ChatLayout `additionalInsets.bottom`: composer height + gap so the last
    /// item is laid out above the floating bar even if `contentInset` is only
    /// the keyboard frame.
    static func layoutBottomPadding(composerHeight: CGFloat, breathing: CGFloat) -> CGFloat {
        (composerHeight > 1 ? composerHeight : 58) + breathing
    }

    /// Called after insets change. `flushingLayout` is true outside collection callbacks.
    var onApplied: ((_ contentBottom: CGFloat, _ layoutBottom: CGFloat, _ flushingLayout: Bool) -> Void)?

    /// Pure overlap math so docked vs accessory insets can be tested without UIKit layout.
    ///
    /// Keyboard visible: cover from the composer top when that top sits at or
    /// above the keyboard edge. A cross-window convert can return the *docked*
    /// composer Y (below the keys) — treat that as keys-only and add composer
    /// height once so the last bubble clears the accessory bar.
    static func overlap(
        isComposerInAccessory: Bool,
        keyboardTop: CGFloat,
        collectionMaxY: CGFloat,
        composerTopInCollection: CGFloat?,
        dockedComposerHeight: CGFloat,
        safeAreaBottom: CGFloat,
        breathing: CGFloat
    ) -> CGFloat {
        let composerH = dockedComposerHeight > 1 ? dockedComposerHeight : 58
        if isComposerInAccessory {
            let coveringTop: CGFloat
            if let composerTop = composerTopInCollection, composerTop <= keyboardTop + 1 {
                coveringTop = composerTop
            } else {
                coveringTop = keyboardTop - composerH
            }
            return max(composerH, collectionMaxY - coveringTop) + breathing
        }
        if let composerTop = composerTopInCollection {
            return max(composerH + safeAreaBottom, collectionMaxY - composerTop) + breathing
        }
        return composerH + safeAreaBottom + breathing
    }

    private func dockedComposerHeight() -> CGFloat {
        composer?.bounds.height ?? 0
    }

    private func composerTopInCollection() -> CGFloat? {
        guard let composer, let collectionView, composer.bounds.height > 1 else { return nil }
        let rect = composer.convert(composer.bounds, to: collectionView)
        guard rect.height > 1, rect.minY.isFinite else { return nil }
        return rect.minY
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
