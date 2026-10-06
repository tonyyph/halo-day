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
    static func save(_ habit: Habit, model: HaloModel, fixture: Bool) {
        #if DEBUG
        if fixture {
            if let index = model.habits.firstIndex(where: { $0.id == habit.id }) { model.habits[index] = habit } else { model.habits.append(habit) }
            return
        }
        #endif
        model.saveHabit(habit)
    }
    static func remove(_ habit: Habit, model: HaloModel, fixture: Bool) {
        #if DEBUG
        if fixture { model.habits.removeAll { $0.id == habit.id }; return }
        #endif
        model.removeHabit(habit.id)
    }
    static func saveCountdown(_ countdown: Countdown, model: HaloModel, fixture: Bool) {
        #if DEBUG
        if fixture { model.countdowns.append(countdown); return }
        #endif
        model.saveCountdown(countdown)
    }
    static func removeCountdown(_ countdown: Countdown, model: HaloModel, fixture: Bool) {
        #if DEBUG
        if fixture { model.countdowns.removeAll { $0.id == countdown.id }; return }
        #endif
        model.removeCountdown(countdown.id)
    }
    @discardableResult
    static func saveSetup(_ setup: LockSetup, model: HaloModel, fixture: Bool) -> Bool {
        #if DEBUG
        if fixture {
            guard model.canSave(setup) else { model.showPaywall = true; return false }
            guard setup.isValid else { return false }
            if let index = model.setups.firstIndex(where: { $0.id == setup.id }) { model.setups[index] = setup } else { model.setups.append(setup) }
            return true
        }
        #endif
        return model.saveSetup(setup)
    }
    static func removeSetup(_ setup: LockSetup, model: HaloModel, fixture: Bool) {
        #if DEBUG
        if fixture { model.setups.removeAll { $0.id == setup.id }; return }
        #endif
        model.removeSetup(setup.id)
    }
    static func applySky(_ sky: SkyID, model: HaloModel, fixture: Bool) {
        #if DEBUG
        if fixture {
            if sky.isPremium && !model.purchases.isPremium { model.showSettings = false; model.showPaywall = true } else { model.settings.skyChoice = sky }
            return
        }
        #endif
        model.applySky(sky)
    }
}
