import SwiftUI
import CoreText
import UIKit

/// Registers the bundled Fraunces faces with CoreText for whichever bundle is running
/// (the app, or the widget extension). Safe to call repeatedly.
enum HaloFonts {
    private static let registered: Bool = {
        let bundles = [Bundle.main, Bundle(for: BundleToken.self)]
        for name in ["HaloFraunces-Display", "HaloFraunces-Text", "HaloFraunces-Italic"] {
            guard UIFont(name: name, size: 12) == nil,
                  let url = bundles.lazy.compactMap({ $0.url(forResource: name, withExtension: "ttf") }).first else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        return true
    }()
    static func registerIfNeeded() { _ = registered }
    private final class BundleToken {}
}

/// Halo Day v2 design tokens. v1 `HaloTokens`/`HaloFont`/`Motion` stay until their screens are removed.
enum DS {
    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let hero: CGFloat = 48
    }
    enum Radius {
        static let control: CGFloat = 14
        static let glass: CGFloat = 22
        static let sheet: CGFloat = 32
    }
    enum Motion {
        static let standard = Animation.spring(response: 0.5, dampingFraction: 0.85)
        static let morph = Animation.spring(response: 0.7, dampingFraction: 0.86)
        static let inkFlip = Animation.easeInOut(duration: 0.6)
        static func resolve(_ animation: Animation, reduceMotion: Bool) -> Animation {
            reduceMotion ? .easeInOut(duration: 0.2) : animation
        }
    }
    enum Typeface {
        static let displayName = "HaloFraunces-Display"
        static let textName = "HaloFraunces-Text"
        static let italicName = "HaloFraunces-Italic"

        static func isAvailable(_ name: String) -> Bool { UIFont(name: name, size: 12) != nil }

        /// Large editorial headings.
        static func display(_ size: CGFloat, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
            custom(displayName, size, style, fallback: .system(size: size, weight: .regular, design: .serif))
        }
        /// Event titles and section headings.
        static func title(_ size: CGFloat, relativeTo style: Font.TextStyle = .title3) -> Font {
            custom(textName, size, style, fallback: .system(size: size, weight: .medium, design: .serif))
        }
        /// The italic moment name under the clock ("Golden hour").
        static func moment(_ size: CGFloat, relativeTo style: Font.TextStyle = .subheadline) -> Font {
            custom(italicName, size, style, fallback: .system(size: size, design: .serif).italic())
        }
        /// Clock numerals; sized by the Orbit, not by Dynamic Type.
        static func clock(_ size: CGFloat) -> Font {
            .system(size: size, weight: .ultraLight, design: .default).monospacedDigit()
        }
        private static func custom(_ name: String, _ size: CGFloat, _ style: Font.TextStyle, fallback: Font) -> Font {
            HaloFonts.registerIfNeeded()
            return isAvailable(name) ? .custom(name, size: size, relativeTo: style) : fallback
        }
    }
}
