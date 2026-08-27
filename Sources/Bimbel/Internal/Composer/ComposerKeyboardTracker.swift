import UIKit
import InputBarAccessoryView

/// Single owner of keyboard-driven composer insets.
///
/// Approach:
/// 1. Zustand B composer is a **subview**, not InputBarAccessoryView chrome.
/// 2. `KeyboardManager` (IBAV) pins that subview to the keyboard, including
///    interactive-dismiss pans (`bind(to: collectionView)`).
/// 3. Collection view `contentInset.bottom` is derived from the composer frame.
///    ChatLayout is not given `additionalSafeAreaInsets` and does not compete
///    with IBAV for inset ownership.
/// 4. A zero-height dummy `inputAccessoryView` on the text view keeps UIKit's
///    keyboard session attached for interactive dismiss without drawing a bar.
/// 5. The attach sheet is presented as `inputView` so the same tracker keeps
///    the composer glued above it.
///
/// `keyboardLayoutGuide` was considered; KeyboardManager already tracks the
/// interactive pan with the finger, which is the hard requirement.
@MainActor
final class ComposerKeyboardTracker {
    private let keyboardManager = KeyboardManager()
    private weak var composer: UIView?
    private weak var collectionView: UICollectionView?
    private var lastInset: CGFloat = -1

    var additionalBottomConstant: () -> CGFloat = { 0 }

    func attach(composer: UIView, collectionView: UICollectionView) {
        self.composer = composer
        self.collectionView = collectionView
        collectionView.keyboardDismissMode = .interactive
        keyboardManager.additionalInputViewBottomConstraintConstant = { [weak self] in
            self?.additionalBottomConstant() ?? 0
        }
        keyboardManager.shouldApplyAdditionBottomSpaceToInteractiveDismissal = true
        // `bind` owns willShow / willChangeFrame / willHide. Do not replace those
        // callbacks — `transition` runs alongside them, and composer layoutSubviews
        // covers interactive-dismiss pans.
        keyboardManager.bind(inputAccessoryView: composer)
        keyboardManager.bind(to: collectionView)
        keyboardManager.transition = { [weak self] _ in
            self?.syncListInsets(flushingLayout: true)
        }
        syncListInsets(flushingLayout: true)
    }

    /// `flushingLayout` may only be true outside collection view callbacks. Forcing a layout
    /// pass from `scrollViewDidScroll` or `viewDidLayoutSubviews` runs while the list is still
    /// dequeuing cells, which trips UIKit's "dequeued view was not returned" assertion.
    func syncListInsets(flushingLayout: Bool = false) {
        guard let composer, let collectionView, composer.superview != nil else { return }
        if flushingLayout {
            composer.superview?.layoutIfNeeded()
        }
        let frame = composer.convert(composer.bounds, to: collectionView)
        let overlap = max(0, collectionView.bounds.maxY - frame.minY)
        guard abs(overlap - lastInset) > 0.5 else { return }
        lastInset = overlap
        var inset = collectionView.contentInset
        inset.bottom = overlap
        collectionView.contentInset = inset
        collectionView.verticalScrollIndicatorInsets.bottom = overlap
        collectionView.scrollIndicatorInsets.bottom = overlap
    }
}
