import Photos
import UIKit

/// Saves images with add-only Photos access; Halo Day never reads the library.
enum PhotoSaver {
    enum Failure: LocalizedError {
        case denied
        var errorDescription: String? { String(localized: "Halo Day can't add to Photos. Allow it in Settings › Privacy › Photos.") }
    }

    /// Ask before rendering, so a denial doesn't waste a full-resolution render.
    static func authorize() async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw Failure.denied }
    }

    static func save(_ image: UIImage) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
    }
}
