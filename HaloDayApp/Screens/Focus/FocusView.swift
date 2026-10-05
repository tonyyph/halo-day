import SwiftUI

struct FocusView: View {
    @Environment(HaloModel.self) private var model
    @State private var minutes = 50
    @State private var title = ""
    @State private var confirmEnd = false
    var body: some View {
        HaloScreen {
            SectionTitle(title: "Make space to focus", subtitle: "One thing. Your full attention.")
            if let session = model.focus, session.isActive {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    VStack(spacing: HaloTokens.Space.section) {
                        ZStack {
                            ProgressRing(progress: 1 - session.remaining(at: context.date) / Double(session.durationMinutes * 60), width: 5)
                            VStack(spacing: HaloTokens.Space.row) {
                                Text(session.title).font(HaloTokens.title)
                                Text(Duration.seconds(session.remaining(at: context.date)), format: .time(pattern: .minuteSecond)).font(.system(size: 60, weight: .light, design: .rounded)).monospacedDigit().minimumScaleFactor(0.5)
                                Text(session.isPaused ? "Paused" : "A little space, just for you.").font(.caption).foregroundStyle(.secondary)
                            }.padding(HaloTokens.Space.hero)
                        }.frame(maxWidth: 300).aspectRatio(1, contentMode: .fit)
                        HStack(spacing: HaloTokens.Space.card) {
                            Button(session.isPaused ? "Resume" : "Pause") { Task { await model.pauseFocus() } }.buttonStyle(HaloButtonStyle())
                            Button("End", role: .destructive) { confirmEnd = true }.frame(minWidth: 80, minHeight: 54)
                        }
                    }.frame(maxWidth: .infinity)
                        .onChange(of: context.date) { _, date in
                            if !session.isPaused && session.endDate <= date { Task { await model.stopFocus(completed: true) } }
                        }
                }
            } else {
                HaloCard {
                    VStack(spacing: HaloTokens.Space.section) {
                        Text("\(minutes)").font(.system(size: 76, weight: .ultraLight, design: .rounded)).monospacedDigit().foregroundStyle(.tint)
                        Text("minutes, beautifully spent").font(.subheadline).foregroundStyle(.secondary)
                        Picker("Duration", selection: $minutes) { Text("25 min").tag(25); Text("50 min").tag(50); Text("90 min").tag(90) }.pickerStyle(.segmented)
                        Stepper("Custom · \(minutes) min", value: $minutes, in: 5...240, step: 5)
                        TextField("Deep work", text: $title).textFieldStyle(.roundedBorder)
                    }
                }
                Button("Begin focus") { Task { await model.startFocus(title: title, minutes: minutes) } }.buttonStyle(HaloButtonStyle())
            }
            HaloCard {
                VStack(alignment: .leading, spacing: HaloTokens.Space.card) {
                    HStack { Text("On your Dynamic Island").font(.headline); Spacer(); if !model.purchases.isPremium { PremiumChip() } }
                    HStack {
                        Image(systemName: "timer").foregroundStyle(PaletteResolver.resolve(model.theme, scheme: .dark).accent)
                        Text(model.focus?.isActive == true ? model.focus!.title : String(localized: "Deep work")).lineLimit(1)
                        Spacer()
                        Text(model.focus?.isActive == true ? Duration.seconds(model.focus!.remaining()).formatted(.time(pattern: .minuteSecond)) : "50:00").monospacedDigit()
                    }.font(.caption).foregroundStyle(PaletteResolver.resolve(model.theme, scheme: .dark).ink).padding(HaloTokens.Space.card).background(PaletteResolver.resolve(ThemeRegistry.theme("graphiteFocus"), scheme: .dark).bg, in: Capsule())
                    Text("Live Activities show your timer on the Lock Screen. Dynamic Island appears on supported iPhones.").font(.caption).foregroundStyle(.secondary)
                    if !model.purchases.isPremium { Button("Unlock Live Activities") { model.showPaywall = true } }
                    else if !model.activities.enabled { Text("Live Activities are turned off for Halo Day in iOS Settings.").font(.caption) }
                }
            }
            if !model.focusHistory.isEmpty {
                Text("Time well spent").font(HaloTokens.title)
                ForEach(model.focusHistory.prefix(7)) { session in
                    HaloCard { HStack { Text(session.title); Spacer(); Text(session.startDate, format: .dateTime.month().day()); Text("\(session.durationMinutes) min").foregroundStyle(.secondary) }.font(.caption) }
                }
            }
        }.confirmationDialog("End this focus session?", isPresented: $confirmEnd, titleVisibility: .visible) { Button("End session", role: .destructive) { Task { await model.stopFocus() } } }
    }
}
