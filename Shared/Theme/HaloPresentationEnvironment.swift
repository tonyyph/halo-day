import SwiftUI

private struct ReferenceDateKey: EnvironmentKey { static let defaultValue: Date? = nil }
private struct ScreenshotModeKey: EnvironmentKey { static let defaultValue = false }

extension EnvironmentValues {
    var haloReferenceDate: Date? {
        get { self[ReferenceDateKey.self] }
        set { self[ReferenceDateKey.self] = newValue }
    }
    var haloScreenshotMode: Bool {
        get { self[ScreenshotModeKey.self] }
        set { self[ScreenshotModeKey.self] = newValue }
    }
}
