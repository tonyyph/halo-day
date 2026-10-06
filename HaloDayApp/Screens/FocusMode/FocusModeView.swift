import SwiftUI

/// Full-screen focus: choose a length on the ring, run it under a dimmed sky, finish with a bloom.
struct FocusModeView: View {
    @Environment(HaloModel.self) private var model
    @Environment(\.haloReferenceDate) private var referenceDate
    @Environment(\.haloScreenshotMode) private var fixture
    @Environment(\.haloReduceMotion) private var reduceMotion
    @State private var minutes = 25
    @State private var title = ""
    @State private var bloom = false

    var body: some View {
        let now = referenceDate ?? .now
        let sky = SkyEngine.focusDusk(SkyEngine.state(sky: model.settings.skyID, at: now, coordinate: model.skyCoordinate))
        ZStack {
            SkyBackground(state: sky)
            Group {
                if let completed = model.completedFocus {
                    completion(completed, sky: sky)
                } else if let session = model.focus, session.isActive {
                    running(session, now: now, sky: sky)
                } else {
                    setup(sky: sky)
                }
            }
            .padding(DS.Space.xl)
        }
        .foregroundStyle(sky.inkColor.color)
        .tint(sky.inkColor.color)
        .environment(\.colorScheme, .dark)
    }

    // MARK: Setup

    private func setup(sky: SkyState) -> some View {
        VStack(spacing: DS.Space.xl) {
            HStack {
                Spacer()
                Button { model.showFocus = false } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                    .haloGlass(Circle(), tint: sky.mid.color)
                    .accessibilityLabel(Text("Close"))
                    .accessibilityIdentifier("focus-close")
            }
            Text("Make space to focus").font(DS.Typeface.display(30, relativeTo: .title)).multilineTextAlignment(.center)
            FocusDialRing(minutes: $minutes, sky: sky).frame(maxWidth: 300)
            HStack(spacing: DS.Space.s) {
                ForEach([25, 50, 90], id: \.self) { value in
                    Button("\(value) min") { minutes = value }.buttonStyle(GlassPillStyle(sky: sky))
                }
            }
            TextField("What are you focusing on?", text: $title)
                .font(DS.Typeface.title(20))
                .multilineTextAlignment(.center)
                .padding(.vertical, DS.Space.m)
                .haloGlass(RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous), tint: sky.mid.color)
            Spacer(minLength: 0)
            Text(model.purchases.isPremium ? "Shows on your Lock Screen and Dynamic Island." : "Premium shows your session on the Lock Screen.")
                .font(.footnote)
                .opacity(SkyEngine.secondaryOpacity)
                .multilineTextAlignment(.center)
            Button { Task { await start() } } label: { Text("Begin focus").font(.headline).frame(maxWidth: .infinity) }
                .buttonStyle(GlassPillStyle(sky: sky))
                .accessibilityIdentifier("focus-start")
        }
    }

    // MARK: Running

    private func running(_ session: FocusSession, now: Date, sky: SkyState) -> some View {
        VStack(spacing: DS.Space.xl) {
            HStack {
                Button { model.showFocus = false } label: { Image(systemName: "chevron.down").frame(width: 44, height: 44) }
                    .haloGlass(Circle(), tint: sky.mid.color)
                    .accessibilityLabel(Text("Minimize"))
                    .accessibilityIdentifier("focus-minimize")
                Spacer()
            }
            VStack(spacing: DS.Space.xs) {
                Text(session.isPaused ? "Paused" : "Focusing").font(.subheadline).opacity(SkyEngine.secondaryOpacity)
                Text(session.title).font(DS.Typeface.title(24, relativeTo: .title2)).multilineTextAlignment(.center)
            }
            FocusCountdownRing(session: session, now: now, sky: sky).frame(maxWidth: 300)
            Spacer(minLength: 0)
            HStack(spacing: DS.Space.m) {
                Button { Task { await pause() } } label: {
                    Label(session.isPaused ? "Resume" : "Pause", systemImage: session.isPaused ? "play.fill" : "pause.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GlassPillStyle(sky: sky))
                .accessibilityIdentifier("focus-pause")
                Button { Task { await stop() } } label: { Text("End").frame(maxWidth: .infinity) }
                    .buttonStyle(GlassPillStyle(sky: sky))
                    .accessibilityIdentifier("focus-end")
            }
        }
    }

    // MARK: Completion

    private func completion(_ session: FocusSession, sky: SkyState) -> some View {
        let minutes = max(1, Int(session.endDate.timeIntervalSince(session.startDate) / 60))
        let today = model.focusSessions
            .filter { !$0.isActive && Calendar.current.isDate($0.startDate, inSameDayAs: referenceDate ?? .now) }
            .reduce(0) { $0 + max(0, Int($1.endDate.timeIntervalSince($1.startDate) / 60)) }
        return VStack(spacing: DS.Space.xl) {
            Spacer()
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [sky.glow.color.opacity(0.75), .clear], center: .center, startRadius: 0, endRadius: 150))
                    .scaleEffect(bloom ? 1.35 : 0.5)
                    .opacity(bloom ? 1 : 0)
                Text(verbatim: "+\(minutes)′").font(DS.Typeface.display(64, relativeTo: .largeTitle))
            }
            .frame(width: 280, height: 280)
            Text("Time well spent.").font(DS.Typeface.title(24, relativeTo: .title2))
            Text("\(today)′ of focus today").opacity(SkyEngine.secondaryOpacity)
            Spacer()
            Button { model.completedFocus = nil; bloom = false; model.showFocus = false } label: { Text("Done").font(.headline).frame(maxWidth: .infinity) }
                .buttonStyle(GlassPillStyle(sky: sky))
                .accessibilityIdentifier("focus-done")
        }
        .onAppear {
            withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.9, dampingFraction: 0.7)) { bloom = true }
        }
        .sensoryFeedback(.success, trigger: bloom) { _, new in new && model.settings.haptics }
    }

    // MARK: Actions (fixture mode never writes storage)

    private func start() async {
        guard fixture else { await model.startFocus(title: title, minutes: minutes); return }
        let start = referenceDate ?? .now
        model.focus = FocusSession(title: title.isEmpty ? String(localized: "Deep work") : title, startDate: start,
                                   endDate: start.addingTimeInterval(Double(minutes * 60)), durationMinutes: minutes, accentColor: "D4AF6A")
    }
    private func pause() async {
        guard fixture else { await model.pauseFocus(); return }
        guard var session = model.focus else { return }
        if let remaining = session.pausedRemaining {
            session.endDate = (referenceDate ?? .now).addingTimeInterval(remaining)
            session.pausedRemaining = nil
        } else {
            session.pausedRemaining = session.remaining(at: referenceDate ?? .now)
        }
        model.focus = session
    }
    private func stop() async {
        if fixture {
            model.focus?.isActive = false
            model.focus?.endDate = referenceDate ?? .now
        } else {
            await model.stopFocus()
        }
        model.showFocus = false
    }
}
