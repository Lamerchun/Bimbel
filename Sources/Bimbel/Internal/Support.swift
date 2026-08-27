import UIKit

enum MaterialFactory {
    /// iOS 26 Liquid Glass when `UIGlassEffect` exists at runtime.
    /// iOS 17/18 fallback is neutral chrome — never a mint-tinted ultraThin overlay.
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
    override init(effect: UIVisualEffect?) {
        super.init(effect: effect)
        isOpaque = false
        backgroundColor = .clear
        contentView.isOpaque = false
        contentView.backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self || hit === contentView ? nil : hit
    }
}

enum NavigationChrome {
    /// System nav bar stays hidden so `material.header` glass can show the list through.
    static func hideSystemBar(in controller: UIViewController, animated: Bool) {
        guard let nav = controller.navigationController else { return }
        nav.setNavigationBarHidden(true, animated: animated)
        nav.navigationBar.isTranslucent = true
        nav.navigationBar.shadowImage = UIImage()
        nav.navigationBar.setBackgroundImage(UIImage(), for: .default)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.shadowColor = nil
        appearance.shadowImage = UIImage()
        appearance.backgroundColor = .clear
        appearance.backgroundEffect = nil
        nav.navigationBar.standardAppearance = appearance
        nav.navigationBar.scrollEdgeAppearance = appearance
        nav.navigationBar.compactAppearance = appearance
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

    static func dateChipText(_ date: Date, calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) { return String(localized: "Today") }
        if calendar.isDateInYesterday(date) { return String(localized: "Yesterday") }
        return dateChip.string(from: date)
    }

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

enum DeliveryTicks {
    /// Thang's overlapping double-tick SVG. Never SF `checkmark` / `checkmark.circle`.
    static func image(for state: DeliveryState) -> UIImage? {
        switch state {
        case .sending:
            return UIImage(systemName: "clock")
        case .sent:
            return drawn(double: false)
        case .delivered, .read:
            return drawn(double: true)
        case .failed:
            return UIImage(systemName: "exclamationmark.circle.fill")
        }
    }

    /// Exact `delivery-double-tick.svg` polylines. Catalog PNGs ship alongside; drawing
    /// is the runtime source of truth so a missed asset cannot fall back to SF checks.
    static func drawn(double: Bool) -> UIImage {
        let size = CGSize(width: double ? 20 : 12, height: 12)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 3
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            func stroke(_ points: [CGPoint]) {
                let path = UIBezierPath()
                path.lineWidth = 1.7
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                path.move(to: points[0])
                points.dropFirst().forEach { path.addLine(to: $0) }
                UIColor.black.setStroke()
                path.stroke()
            }
            stroke([CGPoint(x: 1.2, y: 6.6), CGPoint(x: 4.2, y: 9.4), CGPoint(x: 10.6, y: 2.4)])
            if double {
                stroke([CGPoint(x: 6.6, y: 6.6), CGPoint(x: 9.6, y: 9.4), CGPoint(x: 16.2, y: 2.4)])
            }
        }
        return image.withRenderingMode(.alwaysTemplate)
    }
}

enum BundleImage {
    static func named(_ name: String) -> UIImage? {
        if let image = UIImage(named: name, in: .module, compatibleWith: nil) {
            return image
        }
        if let url = Bundle.module.url(forResource: name, withExtension: "png"),
           let image = UIImage(contentsOfFile: url.path)
        {
            return image
        }
        return pdf(name)
    }

    static func template(_ name: String) -> UIImage? {
        named(name)?.withRenderingMode(.alwaysTemplate)
    }

    static func pdf(_ name: String) -> UIImage? {
        guard let url = Bundle.module.url(forResource: name, withExtension: "pdf"),
              let document = CGPDFDocument(url as CFURL),
              let page = document.page(at: 1)
        else { return nil }
        let rect = page.getBoxRect(.mediaBox)
        let renderer = UIGraphicsImageRenderer(size: rect.size)
        return renderer.image { ctx in
            ctx.cgContext.translateBy(x: 0, y: rect.height)
            ctx.cgContext.scaleBy(x: 1, y: -1)
            ctx.cgContext.drawPDFPage(page)
        }
    }
}

enum DoodleWallpaper {
    static func color(base: UIColor) -> UIColor {
        UIColor { traits in
            let name = traits.userInterfaceStyle == .dark
                ? "wallpaper-bimbel-dark"
                : "wallpaper-bimbel-light"
            if let image = BundleImage.named(name) {
                return UIColor(patternImage: image)
            }
            return base.resolvedColor(with: traits)
        }
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
