import SwiftUI

struct RitualsView: View {
    @Environment(HaloModel.self) private var model
    @State private var showAdd = false
    @State private var editing: Habit?
    var body: some View {
        HaloScreen {
            SectionTitle(title: "Rituals, kept gently", subtitle: "Small, daily things. A little water, a page, a walk.")
            HaloCard {
                HStack(spacing: HaloTokens.Space.hero) {
                    ProgressRing(progress: Double(model.completedHabits) / Double(max(1, model.habits.count))).frame(width: 90, height: 90)
                    VStack(alignment: .leading, spacing: HaloTokens.Space.small) {
                        Text("\(model.completedHabits) / \(model.habits.count)").font(HaloTokens.display)
                        Text(model.completedHabits == model.habits.count && !model.habits.isEmpty ? "Beautifully kept." : "One small thing at a time.").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
            if model.habits.isEmpty { EmptyState(icon: "leaf", title: "Begin a ritual", message: "Small, daily things. Water, a page, a walk.") }
            ForEach(model.habits) { habit in
                HaloCard {
                    VStack(alignment: .leading, spacing: HaloTokens.Space.row) {
                        HStack(spacing: HaloTokens.Space.row) {
                            Button { model.toggleHabit(habit) } label: { Image(systemName: habit.isCompleted() ? "checkmark.circle.fill" : "circle").font(.title2).frame(width: 44, height: 44) }.accessibilityLabel(Text("Complete \(habit.title)"))
                            VStack(alignment: .leading, spacing: HaloTokens.Space.tiny) {
                                Label(habit.title, systemImage: habit.icon).font(.headline)
                                Text("\(habit.streakCount) day streak").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Menu {
                                Button("Edit") { editing = habit }
                                Button("Delete", role: .destructive) { model.removeHabit(habit.id) }
                            } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }.accessibilityLabel("Ritual options")
                        }
                        HStack(spacing: HaloTokens.Space.small) {
                            ForEach(0..<7) { offset in
                                let day = Calendar.current.date(byAdding: .day, value: offset - 6, to: .now)!
                                VStack(spacing: HaloTokens.Space.tiny) {
                                    Text(day, format: .dateTime.weekday(.narrow)).font(.caption2)
                                    Image(systemName: habit.isCompleted(on: day) ? "circle.fill" : "circle").foregroundStyle(.tint)
                                }.frame(maxWidth: .infinity).accessibilityLabel(Text(day, format: .dateTime.weekday().day())).accessibilityValue(habit.isCompleted(on: day) ? "Completed" : "Not completed")
                            }
                        }
                    }
                }
            }
            Button("Add a ritual") { showAdd = true }.buttonStyle(HaloButtonStyle())
            HaloCard {
                HaloWidgetContent(date: .now, type: .ritual, size: .rectangular, theme: model.theme, events: [], habits: model.habits, focus: nil, countdown: nil).frame(height: 70)
            }
        }.sheet(isPresented: $showAdd) { HabitEditorView() }.sheet(item: $editing) { HabitEditorView(habit: $0) }
    }
}
struct HabitEditorView: View {
    @Environment(HaloModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var habit: Habit?
    @State private var title = ""
    @State private var icon = "drop"
    private let icons = ["drop", "book.closed", "figure.walk", "leaf", "sun.max", "moon", "pencil", "heart"]
    var body: some View {
        NavigationStack {
            HaloScreen {
                SectionTitle(title: habit == nil ? "A small beginning" : "Your ritual")
                HaloCard {
                    VStack(spacing: HaloTokens.Space.card) {
                        TextField("Ritual name", text: $title).textFieldStyle(.roundedBorder)
                        Picker("Symbol", selection: $icon) { ForEach(icons, id: \.self) { Label($0, systemImage: $0).tag($0) } }
                    }
                }
                Button("Save ritual") {
                    var value = habit ?? Habit(title: title, icon: icon, accentColor: model.theme.accentColor)
                    value.title = title.trimmingCharacters(in: .whitespaces); value.icon = icon
                    model.saveHabit(value); dismiss()
                }.buttonStyle(HaloButtonStyle()).disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }.toolbar { Button("Close") { dismiss() } }
        }.onAppear { title = habit?.title ?? ""; icon = habit?.icon ?? "drop" }
    }
}
