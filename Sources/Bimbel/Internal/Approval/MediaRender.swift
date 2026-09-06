import AVFoundation
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

    static func paint(
        strokes: [MediaStroke],
        texts: [MediaTextOverlay],
        on image: UIImage,
        theme: ConversationTheme
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: image.size))
            let cg = context.cgContext
            cg.setStrokeColor(theme.colors.accent.cgColor)
            cg.setLineCap(.round)
            cg.setLineJoin(.round)
            for stroke in strokes where stroke.points.count > 1 {
                cg.setLineWidth(stroke.width)
                cg.beginPath()
                let first = denormalize(stroke.points[0], in: image.size)
                cg.move(to: first)
                for point in stroke.points.dropFirst() {
                    cg.addLine(to: denormalize(point, in: image.size))
                }
                cg.strokePath()
            }
            for overlay in texts {
                let text = overlay.text as NSString
                let font = theme.fonts.bubbleBody
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor.white
                ]
                let size = text.size(withAttributes: attributes)
                let pad = CGSize(width: 14, height: 8)
                let box = CGSize(width: size.width + pad.width * 2, height: size.height + pad.height * 2)
                let center = denormalize(overlay.normalizedCenter, in: image.size)
                let frame = CGRect(
                    x: center.x - box.width / 2,
                    y: center.y - box.height / 2,
                    width: box.width,
                    height: box.height
                )
                let path = UIBezierPath(roundedRect: frame, cornerRadius: 10)
                UIColor.black.withAlphaComponent(0.28).setFill()
                path.fill()
                UIColor.white.withAlphaComponent(0.92).setFill()
                UIBezierPath(roundedRect: frame.insetBy(dx: 1.5, dy: 1.5), cornerRadius: 8).fill()
                text.draw(
                    in: CGRect(x: frame.minX + pad.width, y: frame.minY + pad.height, width: size.width, height: size.height),
                    withAttributes: [
                        .font: font,
                        .foregroundColor: UIColor(white: 0.12, alpha: 1)
                    ]
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
        completion: @escaping ([OutgoingMedia]) -> Void
    ) {
        let group = DispatchGroup()
        var slots: [OutgoingMedia?] = Array(repeating: nil, count: session.items.count)
        for (index, item) in session.items.enumerated() {
            switch item.kind {
            case .image:
                if let image = composite(item, theme: theme),
                   let data = jpegData(from: image) {
                    slots[index] = OutgoingMedia(
                        id: item.id,
                        kind: .image,
                        source: .data(data),
                        width: Int(image.size.width * image.scale),
                        height: Int(image.size.height * image.scale)
                    )
                }
            case .video:
                guard let url = item.videoURL else { continue }
                if let trim = item.trim, needsTrim(trim, duration: item.duration) {
                    group.enter()
                    trimVideo(url: url, range: trim) { trimmed in
                        let out = trimmed ?? url
                        slots[index] = OutgoingMedia(
                            id: item.id,
                            kind: .video,
                            source: .url(out),
                            width: item.pixelWidth,
                            height: item.pixelHeight,
                            duration: trim.end - trim.start
                        )
                        group.leave()
                    }
                } else {
                    slots[index] = OutgoingMedia(
                        id: item.id,
                        kind: .video,
                        source: .url(url),
                        width: item.pixelWidth,
                        height: item.pixelHeight,
                        duration: item.duration
                    )
                }
            }
        }
        group.notify(queue: .main) {
            completion(slots.compactMap { $0 })
        }
    }

    static func needsTrim(_ trim: MediaVideoTrim, duration: TimeInterval?) -> Bool {
        let end = duration ?? trim.end
        return trim.start > 0.05 || trim.end < end - 0.05
    }

    static func trimVideo(url: URL, range: MediaVideoTrim, completion: @escaping (URL?) -> Void) {
        let asset = AVURLAsset(url: url)
        let preset = AVAssetExportPresetHighestQuality
        guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
            completion(nil)
            return
        }
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("bimbel-trim-\(UUID().uuidString).mp4")
        session.outputURL = dest
        session.outputFileType = .mp4
        let start = CMTime(seconds: max(0, range.start), preferredTimescale: 600)
        let end = CMTime(seconds: max(range.start + 0.1, range.end), preferredTimescale: 600)
        session.timeRange = CMTimeRange(start: start, end: end)
        session.exportAsynchronously {
            DispatchQueue.main.async {
                completion(session.status == .completed ? dest : nil)
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
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            context.cgContext.translateBy(x: size.width / 2, y: size.height / 2)
            context.cgContext.rotate(by: .pi / 2)
            image.draw(in: CGRect(x: -image.size.width / 2, y: -image.size.height / 2, width: image.size.width, height: image.size.height))
        }
    }

    private static func denormalize(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: point.x * size.width, y: point.y * size.height)
    }
}
