import ActivityKit
import WidgetKit
import SwiftUI

struct HaloFocusLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HaloActivityAttributes.self) { context in
            let colors = PaletteResolver.resolve(ThemeRegistry.theme(context.attributes.themeId), scheme: .dark)
            HaloActivityBanner(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(colors.surface.opacity(0.85))
                .activitySystemActionForegroundColor(colors.accent)
                .widgetURL(URL(string: context.attributes.isEvent ? "haloday://today" : "haloday://focus"))
        } dynamicIsland: { context in
            let colors = PaletteResolver.resolve(ThemeRegistry.theme(context.attributes.themeId), scheme: .dark)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(spacing: 4) {
                        Image(systemName: context.attributes.isEvent ? "calendar" : "timer")
                            .foregroundStyle(colors.accent)
                            .frame(width: 36, height: 36)
                            .background(colors.accentSoft, in: Circle())
                        Text(context.attributes.isEvent ? "Calendar" : "Focus").font(.caption2)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    timer(context).font(.system(.title2, design: .rounded)).monospacedDigit().frame(maxWidth: 110)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.title).font(.system(.headline, design: .serif)).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 10) {
                        if context.state.pausedRemaining == nil && context.state.phase != "finished" {
                            ProgressView(timerInterval: context.attributes.startDate...max(context.attributes.startDate.addingTimeInterval(1), context.state.endDate), countsDown: false)
                                .tint(colors.accent)
                        }
                        HStack {
                            if !context.attributes.isEvent && context.state.phase != "finished" {
                                Button(intent: PauseFocusIntent()) { ActivityControlLabel(paused: context.state.pausedRemaining != nil) }
                                Spacer()
                                Button(intent: EndFocusIntent()) { Label("End", systemImage: "stop.fill") }
                            } else { Link("Open Halo Day", destination: URL(string: "haloday://today")!) }
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .tint(colors.accent)
                    }
                }
            } compactLeading: {
                Image(systemName: context.attributes.isEvent ? "calendar" : "timer").foregroundStyle(colors.accent)
            } compactTrailing: {
                timer(context).font(.caption2.monospacedDigit()).frame(width: 52)
            } minimal: {
                if context.state.phase == "finished" { Image(systemName: "checkmark.circle").foregroundStyle(colors.accent) }
                else if context.state.pausedRemaining != nil { Image(systemName: "pause.circle").foregroundStyle(colors.accent) }
                else {
                    ProgressView(timerInterval: context.attributes.startDate...max(context.attributes.startDate.addingTimeInterval(1), context.state.endDate), countsDown: false)
                        .progressViewStyle(.circular)
                        .tint(colors.accent)
                }
            }
            .keylineTint(colors.accent)
            .widgetURL(URL(string: "haloday://focus"))
        }
    }

    private func timer(_ context: ActivityViewContext<HaloActivityAttributes>) -> some View {
        HaloActivityTimer(start: context.attributes.startDate, end: context.state.endDate,
                          remaining: context.state.pausedRemaining, phase: context.state.phase)
    }
}
