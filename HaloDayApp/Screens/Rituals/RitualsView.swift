import SwiftUI

struct RitualsView: View {
    @Environment(HaloModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.haloToasts) private var toasts
    @Environment(\.haloReduceMotion) private var reduceMotion
    @Environment(\.haloHapticsEnabled) private var haptics
    @AppStorage("halo.lastRitualCelebration") private var lastCelebration = ""

    @State private var showAdd = false
    @State private var editing: Habit?
    @State private var detail: Habit?
    @State private var deleting: Habit?
    @State private var celebrating = false

    var body: some View {
        ZStack {
            ThemeBackground()
            List {
                Section {
                    SectionTitle(
                        title: "Rituals, kept gently",
                        subtitle: "Small, daily things. A little water, a page, a walk."
                    )
                    RitualDailyHero(habits: model.habits, celebrating: celebrating)
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
                            RitualRow(habit: habit) { detail = habit } onToggle: {
                                withAnimation(Motion.resolve(Motion.snappy, reduceMotion: reduceMotion)) {
                                    model.toggleHabit(habit)
                                }
                            }
                            .listRowBackground(palette.surfaceSunken)
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button("Complete ritual", systemImage: "checkmark") { model.toggleHabit(habit) }
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
                        date: .now, type: .ritual, size: .rectangular,
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
        .toolbar { EditButton() }
        .sheet(isPresented: $showAdd) { HabitEditorView().haloSheet([.large]) }
        .sheet(item: $editing) { HabitEditorView(habit: $0).haloSheet([.large]) }
        .sheet(item: $detail) { habit in
            RitualDetailView(habit: habit) {
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
        .onChange(of: model.completedHabits) { old, new in
            guard old < new && new == model.habits.count && new > 0 else { return }
            let parts = Calendar.current.dateComponents([.year, .month, .day], from: .now)
            let key = "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
            guard lastCelebration != key else { return }
            lastCelebration = key
            celebrating = true
            toasts?.show("All done today")
            Task {
                try? await Task.sleep(for: .seconds(2.2))
                celebrating = false
            }
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
