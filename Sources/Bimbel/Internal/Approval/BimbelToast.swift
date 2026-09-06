import UIKit

enum BimbelToast {
    static func show(_ text: String, in view: UIView, theme: ConversationTheme) {
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
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24)
        ])
        label.layoutMargins = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        let inset = UIView()
        inset.isUserInteractionEnabled = false
        label.addSubview(inset)
        NSLayoutConstraint.activate([
            label.heightAnchor.constraint(greaterThanOrEqualToConstant: 36)
        ])
        label.alpha = 0
        UIView.animate(withDuration: 0.2) { label.alpha = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            UIView.animate(withDuration: 0.25, animations: { label.alpha = 0 }) { _ in
                label.removeFromSuperview()
            }
        }
    }

    private static let tag = 81_140
}
