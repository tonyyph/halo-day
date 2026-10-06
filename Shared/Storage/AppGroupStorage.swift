import Foundation
import WidgetKit

/// Each domain has its own atomic file. NSFileCoordinator protects read-modify-write
/// across the app and AppIntent extension, avoiding lost ritual completions.
struct AppGroupStorage: Sendable {
    static let groupID = "group.co.haloday.shared"
    static let shared = AppGroupStorage()
    let directory: URL
    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.groupID)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("HaloDay", isDirectory: true)
    }
    func read<T: Decodable>(_ key: String, fallback: T) -> T {
        let url = directory.appendingPathComponent(key + ".json")
        var value = fallback
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: nil) { path in
            if let data = try? Data(contentsOf: path), let decoded = try? JSONDecoder().decode(T.self, from: data) { value = decoded }
        }
        return value
    }
    func write<T: Encodable>(_ value: T, key: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(value)
        let url = directory.appendingPathComponent(key + ".json")
        var coordinationError: NSError?
        var writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { path in
            do { try data.write(to: path, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]) }
            catch { writeError = error }
        }
        if let error = coordinationError ?? writeError as NSError? { throw error }
    }
    func toggleHabit(_ id: UUID, on date: Date = .now) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("habits.json")
        var coordinationError: NSError?
        var mutationError: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, options: [], error: &coordinationError) { path in
            do {
                var habits = (try? Data(contentsOf: path)).flatMap { try? JSONDecoder().decode([Habit].self, from: $0) } ?? MockData.habits
                if let index = habits.firstIndex(where: { $0.id == id }) { habits[index].toggle(on: date) }
                try JSONEncoder().encode(habits).write(to: path, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            } catch { mutationError = error }
        }
        if let error = coordinationError ?? mutationError as NSError? { throw error }
        WidgetCenter.shared.reloadAllTimelines()
    }
    var settings: UserSettings { read("settings", fallback: UserSettings()) }
    var habits: [Habit] { read("habits", fallback: MockData.habits) }
    var presets: [WidgetPreset] { read("presets", fallback: []) }
    var focus: FocusSession? { read("focus", fallback: Optional<FocusSession>.none) }
    var snapshot: CalendarSnapshot { read("calendar", fallback: CalendarSnapshot(events: MockData.events())) }
    var countdowns: [Countdown] { read("countdowns", fallback: []) }
    /// v2 setups; the first read after the update migrates v1 presets once.
    /// v2 setups. Migration from v1 presets runs only when the file has never existed, inside one coordinated
    /// write (app and widget extension may race); an unreadable file is never replaced.
    var setups: [LockSetup] {
        let url = directory.appendingPathComponent("setups.v2.json")
        if FileManager.default.fileExists(atPath: url.path) { return read("setups.v2", fallback: []) }
        var result: [LockSetup] = []
        let legacy = presets
        let legacyActive = read("activePreset", fallback: "")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        NSFileCoordinator().coordinate(writingItemAt: url, options: [], error: nil) { path in
            if let data = try? Data(contentsOf: path) {
                result = (try? JSONDecoder().decode([LockSetup].self, from: data)) ?? []
                return
            }
            result = legacy.map(LockSetup.init(legacy:))
            try? JSONEncoder().encode(result).write(to: path, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
        if !legacyActive.isEmpty, activeSetupID == nil, result.contains(where: { $0.id.uuidString == legacyActive }) {
            try? write(legacyActive, key: "activeSetup.v2")
        }
        return result
    }
    var activeSetupID: UUID? { UUID(uuidString: read("activeSetup.v2", fallback: "")) }
}
