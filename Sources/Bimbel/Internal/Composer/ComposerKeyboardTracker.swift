import UIKit

/// Single owner of conversation **list** insets.
///
/// The composer stays in the conversation VC and pins to `keyboardLayoutGuide`
/// (Signal-iOS `ConversationBottomBar`). This tracker does **not** position the
/// composer. Covering edge is the composer top + `listComposerGap` (8). Do not
/// add keyboard height on top of that — the bar is already on the layout guide.
/// Residual tail lives inside the cell.
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
    private var observers: [NSObjectProtocol] = []

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
        collectionView: UICollectionView
    ) {
        self.host = host
        self.composer = composer
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
        collectionView?.keyboardDismissMode = dismissPanEnabled ? .interactive : .none
    }

    func syncListInsets(flushingLayout: Bool = false) {
        guard let host, let collectionView else { return }
        insetMutationDepth += 1
        defer { insetMutationDepth -= 1 }
        if flushingLayout {
            host.layoutIfNeeded()
        }
        let overlap = Self.overlap(
            collectionMaxY: collectionView.bounds.maxY,
            composerTopInCollection: composerTopInCollection(),
            composerHeight: composerHeight(),
            safeAreaBottom: host.safeAreaInsets.bottom,
            listComposerGap: listComposerGap
        )
        let padding = Self.layoutBottomPadding(
            composerHeight: composerHeight(),
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
    /// is only catching up. Does not add residual tail (that is inside the cell).
    static func layoutBottomPadding(composerHeight: CGFloat, listComposerGap: CGFloat) -> CGFloat {
        (composerHeight > 1 ? composerHeight : 58) + listComposerGap
    }

    /// Called after insets change. `flushingLayout` is true outside collection callbacks.
    var onApplied: ((_ contentBottom: CGFloat, _ layoutBottom: CGFloat, _ flushingLayout: Bool) -> Void)?

    /// Pure overlap math. Covering edge is the **composer top** (already on
    /// `keyboardLayoutGuide`). `contentInset.bottom` = distance from the list
    /// bottom to that edge + `listComposerGap` (8). Do not add keyboard height
    /// on top — that double-counts the keys the bar is already sitting on.
    static func overlap(
        collectionMaxY: CGFloat,
        composerTopInCollection: CGFloat?,
        composerHeight: CGFloat,
        safeAreaBottom: CGFloat,
        listComposerGap: CGFloat
    ) -> CGFloat {
        let composerH = composerHeight > 1 ? composerHeight : 58
        if let composerTop = composerTopInCollection {
            return max(composerH, collectionMaxY - composerTop) + listComposerGap
        }
        return composerH + safeAreaBottom + listComposerGap
    }

    private func composerHeight() -> CGFloat {
        composer?.bounds.height ?? 0
    }

    private func composerTopInCollection() -> CGFloat? {
        guard let composer, let collectionView, composer.bounds.height > 1 else { return nil }
        let rect = composer.convert(composer.bounds, to: collectionView)
        guard rect.height > 1, rect.minY.isFinite else { return nil }
        return rect.minY
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
        // Frame is copied for Swift 6 isolation only. Covering edge is composer top,
        // never this keyboard rect — the bar is already on `keyboardLayoutGuide`.
        _ = frame
        syncListInsets(flushingLayout: flushingLayout)
    }

    private func removeObservers() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers = []
    }
}
