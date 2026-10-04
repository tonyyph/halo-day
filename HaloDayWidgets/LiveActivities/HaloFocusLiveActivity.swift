import ActivityKit
import WidgetKit
import SwiftUI

struct HaloFocusLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HaloActivityAttributes.self) { context in
            let theme = ThemeRegistry.theme(context.attributes.themeId)
            VStack(alignment: .leading, spacing: HaloTokens.Space.row) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: HaloTokens.Space.small) {
                        Label(context.attributes.isEvent ? "COUNTDOWN" : "FOCUS", systemImage: context.attributes.isEvent ? "calendar" : "timer").font(.caption2.bold()).tracking(1.2)
                        Text(context.attributes.title).font(.system(.title2, design: .serif)).lineLimit(2)
                    }
                    Spacer()
                    ActivityTimer(context: context).font(.system(.title, design: .rounded)).monospacedDigit().frame(maxWidth: 115)
                }
                if context.state.pausedRemaining == nil && context.state.phase != "finished" {
                    ProgressView(timerInterval: context.attributes.startDate...max(context.attributes.startDate.addingTimeInterval(1), context.state.endDate), countsDown: false).tint(Color(hex: context.attributes.accentColor))
                }
                if !context.attributes.isEvent && context.state.phase != "finished" {
                    HStack {
                        Button(intent: PauseFocusIntent()) { Label(context.state.pausedRemaining == nil ? "Pause" : "Resume", systemImage: context.state.pausedRemaining == nil ? "pause" : "play") }
                        Spacer()
                        Button(intent: EndFocusIntent()) { Label("End", systemImage: "stop") }
                    }.font(.caption).buttonStyle(.bordered)
                }
            }.padding(HaloTokens.Space.card)
                .foregroundStyle(Color(hex: theme.dark.ink))
                .activityBackgroundTint(Color(hex: theme.dark.bg))
                .activitySystemActionForegroundColor(Color(hex: theme.dark.ink))
                .widgetURL(URL(string: context.attributes.isEvent ? "haloday://today" : "haloday://focus"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.isEvent ? "Calendar" : "Focus", systemImage: context.attributes.isEvent ? "calendar" : "timer").font(.caption).foregroundStyle(Color(hex: context.attributes.accentColor))
                }
                DynamicIslandExpandedRegion(.trailing) { ActivityTimer(context: context).font(.title2.monospacedDigit()).frame(maxWidth: 110) }
                DynamicIslandExpandedRegion(.center) { Text(context.attributes.title).font(.system(.headline, design: .serif)).lineLimit(1) }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        if !context.attributes.isEvent {
                            Button(intent: PauseFocusIntent()) { Label(context.state.pausedRemaining == nil ? "Pause" : "Resume", systemImage: "pause.circle") }
                            Spacer()
                            Button(intent: EndFocusIntent()) { Label("End", systemImage: "stop.circle") }
                        } else { Link("Open Halo Day", destination: URL(string: "haloday://today")!) }
                    }.font(.caption).tint(Color(hex: context.attributes.accentColor))
                }
            } compactLeading: {
                Image(systemName: context.attributes.isEvent ? "calendar" : "timer").foregroundStyle(Color(hex: context.attributes.accentColor))
            } compactTrailing: {
                ActivityTimer(context: context).font(.caption2.monospacedDigit()).frame(width: 48)
            } minimal: {
                Image(systemName: context.state.pausedRemaining == nil ? "timer" : "pause.circle").foregroundStyle(Color(hex: context.attributes.accentColor))
            }.keylineTint(Color(hex: context.attributes.accentColor))
                .widgetURL(URL(string: "haloday://focus"))
        }
    }
}
struct ActivityTimer: View {
    var context: ActivityViewContext<HaloActivityAttributes>
    var body: some View {
        if context.state.phase == "finished" { Text("Done") }
        else if let remaining = context.state.pausedRemaining { Text(Duration.seconds(remaining), format: .time(pattern: .minuteSecond)) }
        else { Text(timerInterval: context.attributes.startDate...max(context.attributes.startDate.addingTimeInterval(1), context.state.endDate), countsDown: true) }
    }
}
