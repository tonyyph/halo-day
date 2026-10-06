import SwiftUI

/// One ritual: its bead, streak, twelve weeks of history, edit and delete.
struct RitualDetailView: View {
    @Environment(HaloModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.haloScreenshotMode) private var fixture
    var habitID: UUID
    @State private var editing = false
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            SkyScreen { sky, now in
                if let habit = model.habits.first(where: { $0.id == habitID }) {
                    ScrollView {
                        VStack(spacing: DS.Space.xl) {
                            RitualBead(habit: habit, done: habit.isCompleted(on: now), size: 88)
                            Text(habit.title)
                                .font(DS.Typeface.display(30, relativeTo: .title))
                                .multilineTextAlignment(.center)
                            HStack(spacing: DS.Space.l) {
                                Text(habit.timeOfDay.title)
                                Text("\(habit.streak(asOf: now)) day streak")
                            }
                            .font(.subheadline)
                            .opacity(SkyEngine.secondaryOpacity)
                            RitualHistoryDots(grid: RitualHistoryBuilder.grid(for: habit, endingOn: now),
                                              color: (SkyColor(hexString: habit.accentColor) ?? sky.glow).color, sky: sky)
                            Button { editing = true } label: { Label("Edit", systemImage: "pencil").frame(maxWidth: .infinity) }
                                .buttonStyle(GlassPillStyle(sky: sky))
                                .accessibilityIdentifier("ritual-edit")
                            Button(role: .destructive) { confirmDelete = true } label: {
                                Label("Delete ritual", systemImage: "trash").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(GlassPillStyle(sky: sky))
                            .accessibilityIdentifier("ritual-delete")
                        }
                        .padding(DS.Space.xl)
                    }
                    .sheet(isPresented: $editing) { RitualEditorView(habit: habit) }
                    .confirmationDialog("Delete this ritual and its history?", isPresented: $confirmDelete, titleVisibility: .visible) {
                        Button("Delete", role: .destructive) {
                            HaloViewActions.remove(habit, model: model, fixture: fixture)
                            dismiss()
                        }
                    }
                }
            }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
