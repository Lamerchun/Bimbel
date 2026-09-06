import UIKit

/// Composer-Drag hit rules. Pan-through only — no visual drag handle.
/// Interactive dismiss may start on Plus, pill chrome, or camera — not the
/// Message caret/selection, not hold-mic.
enum ComposerChromeDismiss {
    static func allowsStart(hitView: UIView?, mic: UIView, textView: UIView) -> Bool {
        guard let hitView else { return false }
        if hitView === mic || hitView.isDescendant(of: mic) { return false }
        if hitView === textView || hitView.isDescendant(of: textView) { return false }
        return true
    }

    static func isVertical(translation: CGPoint, velocity: CGPoint) -> Bool {
        let dy = abs(velocity.y) >= abs(translation.y) ? velocity.y : translation.y
        let dx = abs(velocity.x) >= abs(translation.x) ? velocity.x : translation.x
        return abs(dy) > abs(dx)
    }
}

/// Chrome-only bounce scroll. UIKit drives interactive keyboard dismiss from a
/// `UIScrollView` that is actually scrolling — injecting touches into
/// `collectionView.panGestureRecognizer` does not start that system gesture.
/// Plus / pill chrome / camera live inside this view; the Message field and
/// hold-mic do not start the pan. The composer stays on `keyboardLayoutGuide`.
final class ComposerDismissScrollView: UIScrollView {
    weak var mic: UIView?
    weak var textView: UIView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        keyboardDismissMode = .interactive
        alwaysBounceVertical = true
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        delaysContentTouches = true
        canCancelContentTouches = true
        isDirectionalLockEnabled = true
        bounces = true
        backgroundColor = .clear
        clipsToBounds = false
        accessibilityIdentifier = "composer.dismiss.scroll"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func touchesShouldCancel(in view: UIView) -> Bool {
        if let textView, view === textView || view.isDescendant(of: textView) { return false }
        if let mic, view === mic || view.isDescendant(of: mic) { return false }
        return true
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === panGestureRecognizer {
            let point = gestureRecognizer.location(in: self)
            let hit = super.hitTest(point, with: nil)
            return ComposerChromeDismiss.allowsStart(
                hitView: hit,
                mic: mic ?? UIView(),
                textView: textView ?? UIView()
            )
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }
}
