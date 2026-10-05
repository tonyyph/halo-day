import SwiftUI

struct LockScreenMock: View {
    var preset: WidgetPreset
    var events: [CalendarEvent]
    var habits: [Habit]
    var focus: FocusSession?
    var countdown: Countdown?
    var date: Date
    var sample = false
    var onSelect: ((WidgetSize) -> Void)?
    var animateSlots = false
    var wallpaper: Image?
    var selectedSlot: Int?
    var selectionPulse = 0
    var onSlotSelect: ((Int, WidgetSize) -> Void)?
    @Environment(\.haloTheme) private var theme
    @Environment(\.palette) private var palette
    @Environment(\.haloReduceMotion) private var reduceMotion
    @Environment(\.haloHapticsEnabled) private var haptics
    @State private var revealedSlots = 0

    var body: some View {
        ZStack {
            ThemeBackground()
            if let wallpaper {
                wallpaper.resizable().scaledToFill().frame(width: 226, height: 430).clipped()
                    .overlay(.black.opacity(0.22))
            }
            VStack(spacing: 12) {
                Text(date, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                    .font(.system(size: 11, weight: .medium)).padding(.top, 48)
                Text(date, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute())
                    .font(.system(size: 54, weight: .light, design: .rounded)).monospacedDigit()
                slot(defaultType: .month, size: .inline, index: 0).frame(height: 17)
                HStack(spacing: 7) {
                    slot(defaultType: .agenda, size: preset.widgetFamily == .circular && selectedSlot == 1 ? .circular : .rectangular, index: 1)
                        .frame(width: preset.widgetFamily == .circular && selectedSlot == 1 ? 48 : 108, height: 58)
                    slot(defaultType: .month, size: .circular, index: 2).frame(width: 39, height: 39)
                    slot(defaultType: .ritual, size: .circular, index: 3).frame(width: 39, height: 39)
                }
                .frame(height: 64)
                Spacer()
                HStack {
                    quickAction("flashlight.off.fill")
                    Spacer()
                    quickAction("camera.fill")
                }
                .padding(.horizontal, 18).padding(.bottom, 24)
                Capsule().fill(palette.ink.opacity(0.45)).frame(width: 68, height: 3).padding(.bottom, 8)
            }
            .padding(.horizontal, 12)
        }
        .foregroundStyle(wallpaper == nil ? palette.ink : .white)
        .sensoryFeedback(.impact(weight: .light), trigger: revealedSlots) { _, _ in haptics && animateSlots && !reduceMotion }
        .task {
            guard animateSlots else { return }
            if reduceMotion { revealedSlots = 4; return }
            for index in 0..<4 {
                try? await Task.sleep(for: .milliseconds(120))
                guard !Task.isCancelled else { return }
                revealedSlots = index + 1
            }
        }
    }

    private func slot(defaultType: WidgetType, size: WidgetSize, index: Int) -> some View {
        let editing = selectedSlot == index
        let legacy = selectedSlot == nil && ((size == preset.widgetFamily && index < 2) || index == 1)
        return HaloWidgetContent(
            date: date, type: editing || legacy ? preset.widgetType : defaultType,
            size: size, theme: theme, events: events, habits: habits, focus: focus, countdown: countdown, sample: sample
        )
        .minimumScaleFactor(0.65)
        .contentShape(Rectangle())
        .onTapGesture { onSelect?(size); onSlotSelect?(index, size) }
        .overlay {
            if editing { SlotSelectionOutline(trigger: selectionPulse) }
        }
        .opacity(!animateSlots || revealedSlots > index ? 1 : 0)
        .offset(y: !animateSlots || revealedSlots > index || reduceMotion ? 0 : -10)
        .animation(Motion.resolve(Motion.bouncy, reduceMotion: reduceMotion), value: revealedSlots)
        .accessibilityLabel(Text(LocalizedStringKey(size.rawValue.capitalized)))
        .accessibilityAddTraits(editing ? [.isSelected] : [])
    }

    private func quickAction(_ symbol: String) -> some View {
        Image(systemName: symbol).font(.system(size: 12))
            .frame(width: 28, height: 28).background(palette.ink.opacity(0.08), in: Circle()).accessibilityHidden(true)
    }
}

private struct SlotSelectionOutline: View {
    var trigger: Int
    @Environment(\.palette) private var palette
    @Environment(\.haloReduceMotion) private var reduceMotion

    var body: some View {
        let color = palette.accent
        Group {
            if reduceMotion {
                RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(color, lineWidth: 1.5)
            } else {
                Color.clear.keyframeAnimator(initialValue: 0.0, trigger: trigger) { _, phase in
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(color, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3], dashPhase: phase))
                } keyframes: { _ in
                    LinearKeyframe(-6, duration: 0.3)
                    LinearKeyframe(-12, duration: 0.3)
                }
            }
        }
        .padding(-3)
        .allowsHitTesting(false)
    }
}
