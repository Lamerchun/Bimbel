import AVFoundation
import Foundation
import Photos
import PhotosUI
import UniformTypeIdentifiers
import UIKit

enum MediaIntakeLoader {
    static func items(
        from results: [PHPickerResult],
        completion: @escaping @MainActor ([EditSession.Item]) -> Void
    ) {
        let group = DispatchGroup()
        let collected = IntakeCollector()
        for (index, result) in results.enumerated() {
            let provider = result.itemProvider
            if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                group.enter()
                provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, _ in
                    defer { group.leave() }
                    guard let url, let copied = copyToTemp(url, ext: url.pathExtension) else { return }
                    let item = EditSession.Item.video(
                        url: copied,
                        poster: MediaRender.poster(for: copied),
                        duration: MediaRender.duration(for: copied)
                    )
                    collected.append((index, item))
                }
            } else if provider.canLoadObject(ofClass: UIImage.self) {
                group.enter()
                provider.loadObject(ofClass: UIImage.self) { object, _ in
                    defer { group.leave() }
                    // Consume `UIImage` inside this callback; only `Data` is stored.
                    guard let image = object as? UIImage,
                          let data = MediaRender.jpegData(from: image)
                    else { return }
                    let item = EditSession.Item.photo(
                        data: data,
                        width: Int(image.size.width * image.scale),
                        height: Int(image.size.height * image.scale)
                    )
                    collected.append((index, item))
                }
            }
        }
        group.notify(queue: .main) {
            let items = collected.sortedItems()
            MainActor.assumeIsolated { completion(items) }
        }
    }

    static func item(fromCamera info: [UIImagePickerController.InfoKey: Any]) -> EditSession.Item? {
        if let url = info[.mediaURL] as? URL {
            let copied = copyToTemp(url, ext: url.pathExtension) ?? url
            return .video(
                url: copied,
                poster: MediaRender.poster(for: copied),
                duration: MediaRender.duration(for: copied)
            )
        }
        if let image = info[.originalImage] as? UIImage, let data = MediaRender.jpegData(from: image) {
            return .photo(
                data: data,
                width: Int(image.size.width * image.scale),
                height: Int(image.size.height * image.scale)
            )
        }
        return nil
    }

    static func item(from asset: PHAsset, completion: @escaping @MainActor (EditSession.Item?) -> Void) {
        if asset.mediaType == .video {
            let options = PHVideoRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                guard let urlAsset = avAsset as? AVURLAsset,
                      let copied = copyToTemp(urlAsset.url, ext: urlAsset.url.pathExtension)
                else {
                    hopToMain { completion(nil) }
                    return
                }
                let item = EditSession.Item.video(
                    url: copied,
                    poster: MediaRender.poster(for: copied),
                    duration: MediaRender.duration(for: copied)
                )
                hopToMain { completion(item) }
            }
            return
        }
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
            guard let data, let image = UIImage(data: data), let jpeg = MediaRender.jpegData(from: image) else {
                hopToMain { completion(nil) }
                return
            }
            let width = Int(image.size.width * image.scale)
            let height = Int(image.size.height * image.scale)
            hopToMain {
                completion(.photo(data: jpeg, width: width, height: height))
            }
        }
    }

    private static func hopToMain(_ work: @escaping @MainActor () -> Void) {
        DispatchQueue.main.async {
            MainActor.assumeIsolated { work() }
        }
    }

    private static func copyToTemp(_ url: URL, ext: String) -> URL? {
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("bimbel-\(UUID().uuidString).\(ext.isEmpty ? "mov" : ext)")
        try? FileManager.default.removeItem(at: dest)
        do {
            try FileManager.default.copyItem(at: url, to: dest)
            return dest
        } catch {
            return nil
        }
    }
}

/// Gathers picker results off the main actor. A class + lock so Swift 6 does not
/// see concurrent mutation of a captured `var`.
private final class IntakeCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var pairs: [(Int, EditSession.Item)] = []

    func append(_ pair: (Int, EditSession.Item)) {
        lock.lock()
        pairs.append(pair)
        lock.unlock()
    }

    func sortedItems() -> [EditSession.Item] {
        lock.lock()
        defer { lock.unlock() }
        return pairs.sorted { $0.0 < $1.0 }.map(\.1)
    }
}
