import SwiftUI

/// Renders wallpapers and share cards to images at their final pixel sizes.
@MainActor
enum ArtRenderer {
    /// 430 × 932 pt at 3× = 1290 × 2796 px (the largest current iPhone screen).
    static func wallpaper(_ art: WallpaperArt) -> UIImage? { render(art, size: CGSize(width: 430, height: 932)) }
    /// 360 × 640 pt at 3× = 1080 × 1920 px (story format).
    static func shareCard(_ art: ShareCardArt) -> UIImage? { render(art, size: CGSize(width: 360, height: 640)) }

    /// Laid out at 393 × 852 pt, rendered at 1290 × 2796 px so it fills every current iPhone.
    static func agendaWallpaper(_ art: AgendaWallpaperArt) -> UIImage? {
        let renderer = ImageRenderer(content: art)
        renderer.scale = 1290 / AgendaWallpaperArt.size.width
        return renderer.uiImage
    }

    private static func render(_ view: some View, size: CGSize) -> UIImage? {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = 3
        return renderer.uiImage
    }
}
