import SwiftUI

/// Count the days to something that matters.
struct CountdownEditorView: View {
    @Environment(HaloModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.haloScreenshotMode) private var fixture
    @State private var title = ""
    @State private var date = Calendar.current.date(byAdding: .day, value: 30, to: .now) ?? .now

    private var limitReached: Bool { !model.purchases.isPremium && !model.countdowns.isEmpty }
    private var trimmed: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            SkyScreen { sky, now in
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Space.xl) {
                        Text("A day worth counting to").font(DS.Typeface.display(28, relativeTo: .title))
                        TextField("Countdown name", text: $title)
                            .font(DS.Typeface.title(20))
                            .padding(DS.Space.m)
                            .haloGlass(RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous), tint: sky.mid.color)
                            .accessibilityIdentifier("countdown-name")
                        DatePicker("Date", selection: $date, in: Calendar.current.startOfDay(for: now)..., displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .padding(DS.Space.s)
                            .haloGlass(RoundedRectangle(cornerRadius: DS.Radius.glass, style: .continuous), tint: sky.mid.color)
                        if limitReached {
                            VStack(alignment: .leading, spacing: DS.Space.s) {
                                Text("Free keeps one countdown. Premium makes room for more.")
                                Button("See Premium") { dismiss(); model.showPaywall = true }
                                    .buttonStyle(GlassPillStyle(sky: sky))
                                    .accessibilityIdentifier("countdown-limit")
                            }
                        }
                    }
                    .padding(DS.Space.xl)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        HaloViewActions.saveCountdown(Countdown(title: trimmed, targetDate: date), model: model, fixture: fixture)
                        dismiss()
                    }
                    .disabled(trimmed.isEmpty || limitReached)
                    .accessibilityIdentifier("countdown-save")
                }
            }
        }
    }
}
