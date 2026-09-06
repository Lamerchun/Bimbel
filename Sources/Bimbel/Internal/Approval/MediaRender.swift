import AVFoundation
import Foundation
import UIKit

enum MediaRender {
    static let jpegQuality: CGFloat = 0.86

    static func image(for item: EditSession.Item) -> UIImage? {
        ImageLoader.image(from: item.original)
    }

    static func composite(_ item: EditSession.Item, theme: ConversationTheme) -> UIImage? {
        guard let base = image(for: item) else { return nil }
        let cropped = apply(crop: item.crop, to: base)
        return paint(strokes: item.strokes, texts: item.texts, on: cropped, theme: theme)
    }

    static func apply(crop: MediaCrop, to image: UIImage) -> UIImage {
        var working = image
        let turns = ((crop.rotationQuarterTurns % 4) + 4) % 4
        for _ in 0..<turns {
            working = rotateRight(working)
        }
        let rect = crop.normalizedRect
        guard rect.width > 0, rect.height > 0,
              abs(rect.width - 1) > 0.002 || abs(rect.height - 1) > 0.002 || abs(rect.minX) > 0.002 || abs(rect.minY) > 0.002
        else { return working }
        let pixel = CGRect(
            x: rect.minX * working.size.width * working.scale,
            y: rect.minY * working.size.height * working.scale,
            width: rect.width * working.size.width * working.scale,
            height: rect.height * working.size.height * working.scale
        ).integral
        guard let cg = working.cgImage, let cut = cg.cropping(to: pixel) else { return working }
        return UIImage(cgImage: cut, scale: working.scale, orientation: .up)
    }

    /// Draws strokes/text onto a copy of `image`. Returns a new image (never optional) so
    /// callers must not `if let` the result — that fails to compile in Swift 6.
    ///
    /// The renderer callback is treated as `@Sendable` under Swift 6.1; copy CG / value
    /// tokens before entering it instead of capturing `UIImage` / `ConversationTheme`.
    static func paint(
        strokes: [MediaStroke],
        texts: [MediaTextOverlay],
        on image: UIImage,
        theme: ConversationTheme
    ) -> UIImage {
        let canvasSize = image.size
        let scale = image.scale
        let baseCG = image.cgImage
        // Fallback only when `cgImage` is nil (CI-backed images). Not Sendable.
        nonisolated(unsafe) let fallbackImage = image
        let accent = theme.colors.accent.cgColor
        let strokeWidth = theme.layout.drawStrokeWidth
        let font = theme.fonts.bubbleBody
        let textColor = ConversationApprovalChrome.textColor
        let scrim = ConversationApprovalChrome.textScrim
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        return renderer.image { context in
            if let baseCG {
                UIImage(cgImage: baseCG, scale: scale, orientation: .up)
                    .draw(in: CGRect(origin: .zero, size: canvasSize))
            } else {
                fallbackImage.draw(in: CGRect(origin: .zero, size: canvasSize))
            }
            let cg = context.cgContext
            cg.setStrokeColor(accent)
            cg.setLineCap(.round)
            cg.setLineJoin(.round)
            for stroke in strokes where stroke.points.count > 1 {
                cg.setLineWidth(strokeWidth)
                cg.beginPath()
                let first = denormalize(stroke.points[0], in: canvasSize)
                cg.move(to: first)
                for point in stroke.points.dropFirst() {
                    cg.addLine(to: denormalize(point, in: canvasSize))
                }
                cg.strokePath()
            }
            for overlay in texts {
                let text = overlay.text as NSString
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: textColor
                ]
                let size = text.size(withAttributes: attributes)
                let pad = CGSize(width: 12, height: 6)
                let box = CGSize(width: size.width + pad.width * 2, height: size.height + pad.height * 2)
                let center = denormalize(overlay.normalizedCenter, in: canvasSize)
                let frame = CGRect(
                    x: center.x - box.width / 2,
                    y: center.y - box.height / 2,
                    width: box.width,
                    height: box.height
                )
                scrim.setFill()
                UIBezierPath(roundedRect: frame, cornerRadius: 8).fill()
                text.draw(
                    in: CGRect(x: frame.minX + pad.width, y: frame.minY + pad.height, width: size.width, height: size.height),
                    withAttributes: attributes
                )
            }
        }
    }

    static func jpegData(from image: UIImage) -> Data? {
        image.jpegData(compressionQuality: jpegQuality)
    }

    static func export(
        _ session: EditSession,
        theme: ConversationTheme,
        completion: @escaping @MainActor ([OutgoingMedia]) -> Void
    ) {
        let group = DispatchGroup()
        let slots = ExportSlotBox(count: session.items.count)
        for (index, item) in session.items.enumerated() {
            switch item.kind {
            case .image:
                if let image = composite(item, theme: theme),
                   let data = jpegData(from: image) {
                    slots.set(
                        OutgoingMedia(
                            id: item.id,
                            kind: .image,
                            source: .data(data),
                            width: Int(image.size.width * image.scale),
                            height: Int(image.size.height * image.scale)
                        ),
                        at: index
                    )
                }
            case .video:
                guard let url = item.videoURL else { continue }
                if let trim = item.trim, needsTrim(trim, duration: item.duration) {
                    group.enter()
                    trimVideo(url: url, range: trim) { trimmed in
                        let out = trimmed ?? url
                        slots.set(
                            OutgoingMedia(
                                id: item.id,
                                kind: .video,
                                source: .url(out),
                                width: item.pixelWidth,
                                height: item.pixelHeight,
                                duration: trim.end - trim.start
                            ),
                            at: index
                        )
                        group.leave()
                    }
                } else {
                    slots.set(
                        OutgoingMedia(
                            id: item.id,
                            kind: .video,
                            source: .url(url),
                            width: item.pixelWidth,
                            height: item.pixelHeight,
                            duration: item.duration
                        ),
                        at: index
                    )
                }
            }
        }
        group.notify(queue: .main) {
            let media = slots.compact()
            MainActor.assumeIsolated { completion(media) }
        }
    }

    static func needsTrim(_ trim: MediaVideoTrim, duration: TimeInterval?) -> Bool {
        let end = duration ?? trim.end
        return trim.start > 0.05 || trim.end < end - 0.05
    }

    /// Do not mark this completion `@Sendable` — it hops to the main actor and is
    /// called from UI export. `AVAssetExportSession` is not Sendable; the session
    /// is only read after export finishes.
    static func trimVideo(url: URL, range: MediaVideoTrim, completion: @escaping @MainActor (URL?) -> Void) {
        let asset = AVURLAsset(url: url)
        let preset = AVAssetExportPresetHighestQuality
        guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
            DispatchQueue.main.async {
                MainActor.assumeIsolated { completion(nil) }
            }
            return
        }
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("bimbel-trim-\(UUID().uuidString).mp4")
        session.outputURL = dest
        session.outputFileType = .mp4
        let start = CMTime(seconds: max(0, range.start), preferredTimescale: 600)
        let end = CMTime(seconds: max(range.start + 0.1, range.end), preferredTimescale: 600)
        session.timeRange = CMTimeRange(start: start, end: end)
        nonisolated(unsafe) let export = session
        export.exportAsynchronously {
            let finished = export.status == .completed
            DispatchQueue.main.async {
                MainActor.assumeIsolated { completion(finished ? dest : nil) }
            }
        }
    }

    static func poster(for url: URL) -> Data? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: 0.05, preferredTimescale: 600)
        guard let cg = try? generator.copyCGImage(at: time, actualTime: nil) else { return nil }
        return jpegData(from: UIImage(cgImage: cg))
    }

    static func duration(for url: URL) -> TimeInterval {
        let seconds = CMTimeGetSeconds(AVURLAsset(url: url).duration)
        return seconds.isFinite ? seconds : 0
    }

    private static func rotateRight(_ image: UIImage) -> UIImage {
        let size = CGSize(width: image.size.height, height: image.size.width)
        let scale = image.scale
        let sourceSize = image.size
        let baseCG = image.cgImage
        nonisolated(unsafe) let fallbackImage = image
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            context.cgContext.translateBy(x: size.width / 2, y: size.height / 2)
            context.cgContext.rotate(by: .pi / 2)
            let rect = CGRect(x: -sourceSize.width / 2, y: -sourceSize.height / 2, width: sourceSize.width, height: sourceSize.height)
            if let baseCG {
                UIImage(cgImage: baseCG, scale: scale, orientation: .up).draw(in: rect)
            } else {
                fallbackImage.draw(in: rect)
            }
        }
    }

    private static func denormalize(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: point.x * size.width, y: point.y * size.height)
    }
}

/// Slot array for `export`. A class + lock so Swift 6 does not see concurrent
/// mutation of a captured `var` from trim callbacks.
private final class ExportSlotBox: @unchecked Sendable {
    private let lock = NSLock()
    private var slots: [OutgoingMedia?]

    init(count: Int) {
        slots = Array(repeating: nil, count: count)
    }

    func set(_ value: OutgoingMedia?, at index: Int) {
        lock.lock()
        slots[index] = value
        lock.unlock()
    }

    func compact() -> [OutgoingMedia] {
        lock.lock()
        defer { lock.unlock() }
        return slots.compactMap { $0 }
    }
}
