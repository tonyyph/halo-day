import Foundation

/// "1 day left" / "12 days left" with English grammar agreement (Vietnamese has no plural: "Còn 12 ngày").
enum DaysLeft {
    static func string(_ days: Int) -> String {
        String(AttributedString(localized: "^[\(days) day](inflect: true) left").characters)
    }
}
