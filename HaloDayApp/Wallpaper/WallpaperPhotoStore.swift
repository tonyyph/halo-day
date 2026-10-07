import UIKit
import CoreImage

/// The person's own wallpaper photos, one per setup, kept in the App Group so the Shortcuts action can use them.
enum WallpaperPhotoStore {
    private static func url(_ setupID: UUID) -> URL {
        AppGroupStorage.shared.directory.appendingPathComponent("wallpaper-\(setupID.uuidString).jpg")
    }

    static func load(_ setupID: UUID) -> UIImage? {
        (try? Data(contentsOf: url(setupID))).flatMap(UIImage.init(data:))
    }

    /// Crops to the Lock Screen's shape at full resolution, saves, and reports whether the photo reads as dark.
    static func save(_ data: Data, for setupID: UUID) throws -> (image: UIImage, isDark: Bool) {
        guard let source = UIImage(data: data) else { throw CocoaError(.fileReadCorruptFile) }
        let target = CGSize(width: 1290, height: 2796)
        let scale = max(target.width / source.size.width, target.height / source.size.height)
        let drawn = CGSize(width: source.size.width * scale, height: source.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            source.draw(in: CGRect(x: (target.width - drawn.width) / 2, y: (target.height - drawn.height) / 2, width: drawn.width, height: drawn.height))
        }
        guard let jpeg = image.jpegData(compressionQuality: 0.9) else { throw CocoaError(.fileWriteUnknown) }
        try FileManager.default.createDirectory(at: AppGroupStorage.shared.directory, withIntermediateDirectories: true)
        try jpeg.write(to: url(setupID), options: .atomic)
        return (image, isDark(image))
    }

    static func remove(_ setupID: UUID) { try? FileManager.default.removeItem(at: url(setupID)) }

    /// Average luminance of the area under the agenda (the middle of the screen).
    static func isDark(_ image: UIImage) -> Bool {
        guard let cg = image.cgImage else { return false }
        let input = CIImage(cgImage: cg)
        let band = CGRect(x: 0, y: input.extent.height * 0.2, width: input.extent.width, height: input.extent.height * 0.5)
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: input, kCIInputExtentKey: CIVector(cgRect: band)]),
              let output = filter.outputImage else { return false }
        var pixel = [UInt8](repeating: 0, count: 4)
        CIContext(options: [.workingColorSpace: NSNull()])
            .render(output, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        let luminance = 0.2126 * Double(pixel[0]) + 0.7152 * Double(pixel[1]) + 0.0722 * Double(pixel[2])
        return luminance < 140
    }
}
