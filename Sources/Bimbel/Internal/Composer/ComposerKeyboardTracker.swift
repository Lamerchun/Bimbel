import UIKit

/// Single owner of conversation **list** insets.
///
/// The composer is not positioned here. When the keyboard is visible it lives in
/// the view controller's `inputAccessoryView` (keyboard window). When hidden it
/// is docked in the conversation VC at the safe-area bottom.
///
/// Insets come from the top of the **composer** (docked or in the accessory)
/// so the last bubble clears the floating bar by `listComposerGap` (8).
/// The covering edge is the composer top, never the keys. A keys-only keyboard
/// frame still adds composer height once so the bar sitting on the keys is
/// cleared. Do not add residual tail — it lives inside the cell.
///
/// `flushingLayout` may only be true outside collection view callbacks. Forcing a
/// layout pass from `scrollViewDidScroll` or `viewDidLayoutSubviews` runs while
/// the list is still dequeuing cells, which trips UIKit's "dequeued view was not
/// returned" assertion.
@MainActor
final class ComposerKeyboardTracker {
    private weak var host: UIView?
    private weak var composer: UIView?
    private weak var accessoryBar: UIView?
    private weak var collectionView: UICollectionView?
    private var lastInset: CGFloat = -1
    private var lastKeyboardFrameInScreen: CGRect?
    private var observers: [NSObjectProtocol] = []

    var isComposerInAccessory = false
    var listComposerGap: CGFloat = ConversationTheme.Layout().listComposerGap
    /// Depth while this tracker writes `contentInset` / notifies `onApplied`.
    /// Nested `scrollViewDidScroll` → `syncListInsets()` must not clear the flag
    /// before the outer write finishes, or `isNearBottom` flips false and the
    /// keyboard-up pin is skipped.
    private var insetMutationDepth = 0
    var isMutatingInsets: Bool { insetMutationDepth > 0 }
    var dismissPanEnabled = true {
        didSet { applyDismissMode() }
    }

    func attach(
        host: UIView,
        composer: UIView,
        accessoryBar: UIView? = nil,
        collectionView: UICollectionView
    ) {
        self.host = host
        self.composer = composer
        self.accessoryBar = accessoryBar
        self.collectionView = collectionView
        applyDismissMode()
        observeKeyboard()
        syncListInsets(flushingLayout: true)
    }

    /// Main-actor teardown. Swift 6 `deinit` is nonisolated and must not read
    /// `observers` (`[any NSObjectProtocol]` is not Sendable).
    func detach() {
        removeObservers()
    }

    func applyDismissMode() {
        collectionView?.keyboardDismissMode = dismissPanEnabled ? .interactiveWithAccessory : .none
    }

    func syncListInsets(flushingLayout: Bool = false) {
        guard let host, let collectionView else { return }
        insetMutationDepth += 1
        defer { insetMutationDepth -= 1 }
        if flushingLayout {
            host.layoutIfNeeded()
        }
        let overlap = Self.overlap(
            isComposerInAccessory: isComposerInAccessory,
            keyboardTop: keyboardTop(in: collectionView, host: host),
            collectionMaxY: collectionView.bounds.maxY,
            composerTopInCollection: composerTopInCollection(),
            composerIsInAccessoryWindow: composerIsInAccessoryWindow,
            dockedComposerHeight: dockedComposerHeight(),
            safeAreaBottom: host.safeAreaInsets.bottom,
            listComposerGap: listComposerGap
        )
        let padding = Self.layoutBottomPadding(
            composerHeight: dockedComposerHeight(),
            listComposerGap: listComposerGap
        )
        let insetChanged = abs(overlap - lastInset) > 0.5
        // Hold `isNearBottom` across the inset write. `contentInset.bottom` growing
        // fires `scrollViewDidScroll` and would otherwise look like a user scroll-away,
        // skipping the keyboard-up pin so the last bubble (and its reaction chip)
        // stays under the composer.
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

    /// Whether the last item is within `threshold` of the visible bottom.
    /// Use the inset from *before* a keyboard-up write; the larger inset alone
    /// makes the same offset look far from the bottom.
    static func isNearBottom(
        contentHeight: CGFloat,
        offsetY: CGFloat,
        boundsHeight: CGFloat,
        adjustedBottomInset: CGFloat,
        threshold: CGFloat = 80
    ) -> Bool {
        let visibleBottom = offsetY + boundsHeight - adjustedBottomInset
        return (contentHeight - visibleBottom) < threshold
    }

    /// ChatLayout `additionalInsets.bottom`: composer height + `listComposerGap`
    /// so the last item is laid out above the floating bar even if `contentInset`
    /// is only the keyboard frame. Does not add residual tail (that is inside the cell).
    static func layoutBottomPadding(composerHeight: CGFloat, listComposerGap: CGFloat) -> CGFloat {
        (composerHeight > 1 ? composerHeight : 58) + listComposerGap
    }

    /// Called after insets change. `flushingLayout` is true outside collection callbacks.
    var onApplied: ((_ contentBottom: CGFloat, _ layoutBottom: CGFloat, _ flushingLayout: Bool) -> Void)?

    /// Pure overlap math so docked vs accessory insets can be tested without UIKit layout.
    ///
    /// Covering edge is the **composer top**, never the keys. `contentInset.bottom`
    /// = distance from the list bottom to that edge + `listComposerGap` (8).
    /// A keys-only keyboard frame still adds composer height once so the bar
    /// sitting on the keys is cleared. Residual tail is not added.
    static func overlap(
        isComposerInAccessory: Bool,
        keyboardTop: CGFloat,
        collectionMaxY: CGFloat,
        composerTopInCollection: CGFloat?,
        composerIsInAccessoryWindow: Bool = false,
        dockedComposerHeight: CGFloat,
        safeAreaBottom: CGFloat,
        listComposerGap: CGFloat
    ) -> CGFloat {
        let composerH = dockedComposerHeight > 1 ? dockedComposerHeight : 58
        if isComposerInAccessory {
            let coveringTop = accessoryCoveringTop(
                keyboardTop: keyboardTop,
                composerTopInCollection: composerTopInCollection,
                composerIsInAccessoryWindow: composerIsInAccessoryWindow,
                composerH: composerH
            )
            return max(composerH, collectionMaxY - coveringTop) + listComposerGap
        }
        if let composerTop = composerTopInCollection {
            return max(composerH + safeAreaBottom, collectionMaxY - composerTop) + listComposerGap
        }
        return composerH + safeAreaBottom + listComposerGap
    }

    /// Top of the accessory bar in collection coordinates.
    /// Never returns the keys-only keyboard top as the covering edge.
    static func accessoryCoveringTop(
        keyboardTop: CGFloat,
        composerTopInCollection: CGFloat?,
        composerIsInAccessoryWindow: Bool,
        composerH: CGFloat
    ) -> CGFloat {
        let barOnKeys = keyboardTop - composerH
        guard let composerTop = composerTopInCollection else { return barOnKeys }
        if composerTop < keyboardTop - 0.5 {
            return composerTop
        }
        if composerIsInAccessoryWindow, abs(composerTop - keyboardTop) <= 1 {
            return composerTop
        }
        return barOnKeys
    }

    private func dockedComposerHeight() -> CGFloat {
        composer?.bounds.height ?? 0
    }

    private var composerIsInAccessoryWindow: Bool {
        guard isComposerInAccessory else { return false }
        guard let bar = accessoryBar ?? composer, let collectionView else { return false }
        guard let window = bar.window else { return false }
        return window !== collectionView.window
    }

    private func composerTopInCollection() -> CGFloat? {
        let bar = (isComposerInAccessory ? accessoryBar : nil) ?? composer
        guard let bar, let collectionView, bar.bounds.height > 1 else { return nil }
        if isComposerInAccessory, bar.window == nil { return nil }
        let rect = bar.convert(bar.bounds, to: collectionView)
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
        removeObservers()
        // Copy the keyboard CGRect in the observer, then hop only that Sendable
        // value. Do not capture `Notification` inside `MainActor.assumeIsolated`.
        addKeyboardObserver(for: UIResponder.keyboardWillShowNotification, flushingLayout: true)
        addKeyboardObserver(for: UIResponder.keyboardWillHideNotification, flushingLayout: true)
        // Interactive dismiss can run during `scrollViewDidScroll`. Do not flush.
        addKeyboardObserver(for: UIResponder.keyboardWillChangeFrameNotification, flushingLayout: false)
        addKeyboardObserver(for: UIResponder.keyboardDidChangeFrameNotification, flushingLayout: false)
    }

    private func addKeyboardObserver(for name: Notification.Name, flushingLayout: Bool) {
        observers.append(NotificationCenter.default.addObserver(
            forName: name,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
            MainActor.assumeIsolated {
                self?.handleKeyboardFrame(frame, flushingLayout: flushingLayout)
            }
        })
    }

    /// `userInfo` is read in the observer callback; only `CGRect?` crosses to the main actor.
    nonisolated static func keyboardFrameEnd(from userInfo: [AnyHashable: Any]?) -> CGRect? {
        userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
    }

    private func handleKeyboardFrame(_ frame: CGRect?, flushingLayout: Bool) {
        lastKeyboardFrameInScreen = frame
        syncListInsets(flushingLayout: flushingLayout)
    }

    private func removeObservers() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers = []
    }
}
