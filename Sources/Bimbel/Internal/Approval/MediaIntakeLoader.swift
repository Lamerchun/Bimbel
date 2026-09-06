import AVFoundation
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
        let lock = NSLock()
        var collected: [(Int, EditSession.Item)] = []
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
                    lock.lock()
                    collected.append((index, item))
                    lock.unlock()
                }
            } else if provider.canLoadObject(ofClass: UIImage.self) {
                group.enter()
                provider.loadObject(ofClass: UIImage.self) { object, _ in
                    defer { group.leave() }
                    guard let image = object as? UIImage,
                          let data = MediaRender.jpegData(from: image)
                    else { return }
                    let item = EditSession.Item.photo(
                        data: data,
                        width: Int(image.size.width * image.scale),
                        height: Int(image.size.height * image.scale)
                    )
                    lock.lock()
                    collected.append((index, item))
                    lock.unlock()
                }
            }
        }
        group.notify(queue: .main) {
            let items = collected.sorted { $0.0 < $1.0 }.map(\.1)
            completion(items)
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
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
                let item = EditSession.Item.video(
                    url: copied,
                    poster: MediaRender.poster(for: copied),
                    duration: MediaRender.duration(for: copied)
                )
                DispatchQueue.main.async { completion(item) }
            }
            return
        }
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
            guard let data, let image = UIImage(data: data), let jpeg = MediaRender.jpegData(from: image) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            DispatchQueue.main.async {
                completion(.photo(
                    data: jpeg,
                    width: Int(image.size.width * image.scale),
                    height: Int(image.size.height * image.scale)
                ))
            }
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
