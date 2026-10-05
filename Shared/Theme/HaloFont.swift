import SwiftUI

enum HaloFont {
    static let displayXL = Font.system(.largeTitle, design: .serif).weight(.regular)
    static let displayL = Font.system(.largeTitle, design: .serif).weight(.regular)
    static let displayM = Font.system(.title2, design: .serif).weight(.medium)
    static let displayS = Font.system(.title3, design: .serif).weight(.medium)
    static let headline = Font.system(.headline, design: .default).weight(.semibold)
    static let body = Font.system(.body, design: .default)
    static let callout = Font.system(.callout, design: .default)
    static let subhead = Font.system(.subheadline, design: .default)
    static let footnote = Font.system(.footnote, design: .default)
    static let caption = Font.system(.caption, design: .default).weight(.medium)
    static let captionUpper = Font.system(.caption2, design: .default).weight(.semibold)
    static let numericHero = Font.system(.largeTitle, design: .rounded).weight(.ultraLight)
    static let numericL = Font.system(.largeTitle, design: .rounded).weight(.light)
    static let numericM = Font.system(.title3, design: .rounded).weight(.medium)
}

private struct CaptionUpperModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.font(HaloFont.captionUpper).textCase(.uppercase).tracking(1.2)
    }
}

extension View {
    func captionUpper() -> some View { modifier(CaptionUpperModifier()) }
}
