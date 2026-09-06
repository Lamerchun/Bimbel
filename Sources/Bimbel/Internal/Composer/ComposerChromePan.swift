import UIKit

/// Composer-Drag hit rules. Interactive dismiss may start on Plus, pill chrome,
/// or camera — not the Message caret/selection, not hold-mic.
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

/// Forwards a vertical chrome pan to `collectionView.panGestureRecognizer` so
/// keyboard + composer ride `keyboardLayoutGuide` as one. Finger-up without a
/// committed dismiss snaps both back (UIKit interactive cancel).
final class ComposerChromePanRecognizer: UIPanGestureRecognizer, UIGestureRecognizerDelegate {
    weak var forwardTo: UIPanGestureRecognizer?
    weak var mic: UIView?
    weak var textView: UIView?

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        delegate = self
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        maximumNumberOfTouches = 1
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        guard isEnabled else { return }
        forwardTo?.touchesBegan(touches, with: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        guard isEnabled else { return }
        forwardTo?.touchesMoved(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        guard isEnabled else { return }
        forwardTo?.touchesEnded(touches, with: event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        guard isEnabled else { return }
        forwardTo?.touchesCancelled(touches, with: event)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        ComposerChromeDismiss.allowsStart(hitView: touch.view, mic: mic ?? UIView(), textView: textView ?? UIView())
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard isEnabled else { return false }
        let translation = translation(in: view)
        let velocity = velocity(in: view)
        return ComposerChromeDismiss.isVertical(translation: translation, velocity: velocity)
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        other === forwardTo
    }
}
