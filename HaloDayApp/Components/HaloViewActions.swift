import SwiftUI

/// Snapshot-only interactions never write fixture data into shared app storage.
@MainActor enum HaloViewActions {
    static func toggle(_ habit: Habit, model: HaloModel, date: Date, fixture: Bool) {
        #if DEBUG
        if fixture {
            if let index = model.habits.firstIndex(where: { $0.id == habit.id }) {
                model.habits[index].toggle(on: date)
            }
            return
        }
        #endif
        model.toggleHabit(habit)
    }
}
