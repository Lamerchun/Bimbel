import UIKit

enum MaterialFactory {
    /// iOS 26 Liquid Glass when `UIGlassEffect` exists at runtime.
    /// iOS 17/18 fallback is `UIBlurEffect.Style.systemUltraThinMaterial`.
    static func makeHeaderEffectView(theme: ConversationTheme) -> UIVisualEffectView {
        if theme.materials.usesLiquidGlassWhenAvailable, let glass = makeLiquidGlassEffect() {
            return NonInteractiveEffectView(effect: glass)
        }
        return NonInteractiveEffectView(effect: UIBlurEffect(style: theme.materials.headerBlurStyle))
    }

    static func makeLiquidGlassEffect() -> UIVisualEffect? {
        guard let effectClass = NSClassFromString("UIGlassEffect") as? NSObject.Type,
              let effect = effectClass.init() as? UIVisualEffect
        else { return nil }
        return effect
    }
}

/// Hairline-free glass that does not eat taps meant for controls.
final class NonInteractiveEffectView: UIVisualEffectView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self || hit === contentView ? nil : hit
    }
}

enum BimbelFormatters {
    static let messageTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    static let dateChip: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE d MMM")
        return formatter
    }()

    static func badgeText(_ value: Int?) -> String? {
        guard let value, value > 0 else { return nil }
        return value > 99 ? "99+" : "\(value)"
    }

    static func relativeTime(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) {
            return messageTime.string(from: date)
        }
        if calendar.isDateInYesterday(date) {
            return String(localized: "Yesterday")
        }
        let startOfNow = calendar.startOfDay(for: now)
        let startOfDate = calendar.startOfDay(for: date)
        if let days = calendar.dateComponents([.day], from: startOfDate, to: startOfNow).day, days < 7 {
            let formatter = DateFormatter()
            formatter.setLocalizedDateFormatFromTemplate("EEE")
            return formatter.string(from: date)
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    static func duration(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

enum ImageLoader {
    static func image(from source: ImageSource?) -> UIImage? {
        guard let source else { return nil }
        switch source {
        case .asset(let name):
            return UIImage(named: name)
        case .data(let data):
            return UIImage(data: data)
        case .url:
            return nil
        }
    }

    @MainActor
    static func load(_ source: ImageSource, completion: @escaping @MainActor (UIImage?) -> Void) {
        switch source {
        case .asset, .data:
            completion(image(from: source))
        case .url(let url):
            URLSession.shared.dataTask(with: url) { data, _, _ in
                // Decode on the main queue so only `Data` crosses the concurrency boundary.
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { completion(data.flatMap(UIImage.init(data:))) }
                }
            }.resume()
        }
    }
}

extension UIView {
    func bimbelPinToEdges(of parent: UIView, insets: UIEdgeInsets = .zero) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: parent.topAnchor, constant: insets.top),
            leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: insets.left),
            trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -insets.right),
            bottomAnchor.constraint(equalTo: parent.bottomAnchor, constant: -insets.bottom)
        ])
    }

    func bimbelCircle(_ size: CGFloat) {
        layer.cornerRadius = size / 2
        layer.masksToBounds = true
        if bounds.width == 0 {
            // applied again in layout if needed
        }
    }
}

final class HitTargetButton: UIButton {
    var minimumHitSize: CGSize = CGSize(width: 44, height: 44)

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let extraW = max(0, (minimumHitSize.width - bounds.width) / 2)
        let extraH = max(0, (minimumHitSize.height - bounds.height) / 2)
        return bounds.insetBy(dx: -extraW, dy: -extraH).contains(point)
    }
}

enum InitialGlyph {
    static func make(title: String, size: CGFloat, colors: ConversationTheme.Colors) -> UIImage {
        let letter = title.trimmingCharacters(in: .whitespacesAndNewlines)
            .first.map { String($0).uppercased() } ?? ""
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { _ in
            colors.accent.setFill()
            UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: size, height: size)).fill()
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: size * 0.38, weight: .semibold),
                .foregroundColor: UIColor.white
            ]
            let textSize = (letter as NSString).size(withAttributes: attributes)
            let origin = CGPoint(x: (size - textSize.width) / 2, y: (size - textSize.height) / 2)
            (letter as NSString).draw(at: origin, withAttributes: attributes)
        }
    }
}
