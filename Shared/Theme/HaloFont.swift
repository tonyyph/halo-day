import SwiftUI

enum HaloFont {
    enum Token {
        case displayXL, displayL, displayM, displayS, headline, body, callout
        case subhead, footnote, caption, captionUpper, numericHero, numericL, numericM

        var size: CGFloat {
            switch self {
            case .displayXL: 44
            case .displayL, .numericL: 34
            case .displayM: 24
            case .displayS, .numericM: 20
            case .headline, .body: 17
            case .callout: 16
            case .subhead: 15
            case .footnote: 13
            case .caption: 12
            case .captionUpper: 11
            case .numericHero: 76
            }
        }

        var style: Font.TextStyle {
            switch self {
            case .displayXL, .displayL, .numericHero, .numericL: .largeTitle
            case .displayM: .title2
            case .displayS, .numericM: .title3
            case .headline: .headline
            case .body: .body
            case .callout: .callout
            case .subhead: .subheadline
            case .footnote: .footnote
            case .caption: .caption
            case .captionUpper: .caption2
            }
        }

        var design: Font.Design {
            switch self {
            case .displayXL, .displayL, .displayM, .displayS: .serif
            case .numericHero, .numericL, .numericM: .rounded
            default: .default
            }
        }

        var weight: Font.Weight {
            switch self {
            case .headline, .captionUpper: .semibold
            case .displayM, .displayS, .caption, .numericM: .medium
            case .numericHero: .ultraLight
            case .numericL: .light
            default: .regular
            }
        }
    }
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
        content.haloFont(.captionUpper).textCase(.uppercase).tracking(1.2)
    }
}

private struct HaloFontModifier: ViewModifier {
    let token: HaloFont.Token
    @ScaledMetric private var size: CGFloat

    init(_ token: HaloFont.Token) {
        self.token = token
        _size = ScaledMetric(wrappedValue: token.size, relativeTo: token.style)
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: token.weight, design: token.design))
    }
}

extension View {
    func captionUpper() -> some View { modifier(CaptionUpperModifier()) }
    func haloFont(_ token: HaloFont.Token) -> some View { modifier(HaloFontModifier(token)) }
}
