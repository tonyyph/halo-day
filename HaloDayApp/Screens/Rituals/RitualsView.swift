import SwiftUI

struct RitualsView: View {
    @Environment(HaloModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.haloReduceMotion) private var reduceMotion
    @Environment(\.haloHapticsEnabled) private var haptics
    @Environment(\.haloReferenceDate) private var referenceDate
    @Environment(\.haloScreenshotMode) private var fixture
    @AppStorage("halo.lastRitualCelebration") private var lastCelebration = ""

    @State private var showAdd = false
    @State private var editing: Habit?
    @State private var detail: Habit?
    @State private var deleting: Habit?
    @State private var celebrating = false

    private var date: Date { referenceDate ?? .now }
    private var completedToday: Int { model.completedHabits(on: date) }

    var body: some View {
        ZStack {
            ThemeBackground()
            List {
                Section {
                    SectionTitle(
                        title: "Rituals, kept gently",
                        subtitle: "Small, daily things. A little water, a page, a walk."
                    )
                    RitualDailyHero(habits: model.habits, date: date, celebrating: celebrating)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))

                if model.habits.isEmpty {
                    EmptyState(icon: "leaf", title: "Begin a ritual", message: "Small, daily things. Water, a page, a walk.")
                        .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(model.habits) { habit in
                            RitualRow(habit: habit, date: date) { detail = habit } onToggle: {
                                toggle(habit)
                            }
                            .listRowBackground(palette.surfaceSunken)
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button("Complete ritual", systemImage: "checkmark") {
                                    toggle(habit)
                                }
                                    .tint(palette.accent)
                            }
                            .swipeActions(edge: .trailing) {
                                Button("Delete", systemImage: "trash", role: .destructive) { deleting = habit }
                                Button("Edit", systemImage: "pencil") { editing = habit }
                            }
                            .contextMenu {
                                Button("Edit") { editing = habit }
                                Button("Delete", role: .destructive) { deleting = habit }
                            }
                        }
                        .onMove { source, destination in
                            withAnimation(Motion.resolve(Motion.smooth, reduceMotion: reduceMotion)) {
                                model.habits.move(fromOffsets: source, toOffset: destination)
                                if let first = model.habits.first { model.saveHabit(first) }
                            }
                        }
                    } header: {
                        Text("Anytime").haloFont(.displayS).textCase(nil)
                    }
                }

                Section {
                    HaloButton(title: "Add a ritual") { showAdd = true }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }

                Section {
                    HaloWidgetContent(
                        date: date, type: .ritual, size: .rectangular,
                        theme: model.theme, events: [], habits: model.habits,
                        focus: nil, countdown: nil
                    )
                    .frame(height: 72)
                    .listRowBackground(palette.surface)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .listSectionSpacing(24)
        }
        .overlay(alignment: .top) {
            if celebrating {
                HaloToast(message: "All done today")
                    .padding(.top, 8)
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(Motion.resolve(Motion.snappy, reduceMotion: reduceMotion), value: celebrating)
        .sensoryFeedback(.success, trigger: celebrating) { _, new in new && haptics }
        .toolbar { EditButton() }
        .sheet(isPresented: $showAdd) { HabitEditorView().haloSheet([.large]) }
        .sheet(item: $editing) { HabitEditorView(habit: $0).haloSheet([.large]) }
        .sheet(item: $detail) { habit in
            RitualDetailView(habit: habit, date: date) {
                detail = nil
                editing = habit
            }
            .haloSheet([.medium, .large])
        }
        .confirmationDialog(
            "Delete ritual?",
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let deleting { model.removeHabit(deleting.id) }
                deleting = nil
            }
        }
        .sensoryFeedback(.warning, trigger: deleting?.id) { _, new in new != nil && haptics }
    }

    private func toggle(_ habit: Habit) {
        let before = completedToday
        withAnimation(Motion.resolve(Motion.snappy, reduceMotion: reduceMotion)) {
            HaloViewActions.toggle(habit, model: model, date: date, fixture: fixture)
        }
        let after = completedToday
        guard before < after && after == model.habits.count && after > 0 else { return }

        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let key = "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
        guard fixture || lastCelebration != key else { return }
        if !fixture { lastCelebration = key }
        celebrating = true
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            celebrating = false
        }
    }
}

#Preview("Rituals · Light") {
    NavigationStack { RitualsView() }.environment(HaloModel())
        .haloTheme(ThemeRegistry.theme("pearlHalo"))
}

#Preview("Rituals · Emerald AX3") {
    NavigationStack { RitualsView() }.environment(HaloModel())
        .haloTheme(ThemeRegistry.theme("emeraldRitual"))
        .environment(\.dynamicTypeSize, .accessibility3)
        .environment(\.haloReduceMotionOverride, true)
}
