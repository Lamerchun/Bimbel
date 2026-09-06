import UIKit

@MainActor
enum BimbelToast {
    static let tag = 81_140

    /// `above` lifts the chip over Approval caption/rail. Default −24 sits under that chrome.
    static func show(
        _ text: String,
        in view: UIView,
        theme: ConversationTheme,
        above: UIView? = nil
    ) {
        view.viewWithTag(Self.tag)?.removeFromSuperview()
        let label = UILabel()
        label.tag = tag
        label.text = text
        label.font = theme.fonts.chip
        label.textColor = theme.colors.systemChipText
        label.textAlignment = .center
        label.numberOfLines = 0
        label.backgroundColor = theme.colors.systemChipFill
        label.layer.cornerRadius = theme.radii.chip
        label.layer.masksToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        let bottom: NSLayoutConstraint
        if let above {
            bottom = label.bottomAnchor.constraint(equalTo: above.topAnchor, constant: -12)
        } else {
            bottom = label.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24)
        }
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            bottom,
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24)
        ])
        label.layoutMargins = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        label.alpha = 0
        UIView.animate(withDuration: 0.2) { label.alpha = 1 }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            UIView.animate(withDuration: 0.25, animations: { label.alpha = 0 }) { _ in
                label.removeFromSuperview()
            }
        }
    }
}
