import ActivityKit
import WidgetKit
import SwiftUI

/// Focus sessions and event countdowns on the Lock Screen and in the Dynamic Island, over the focus-dusk sky.
struct HaloFocusLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HaloActivityAttributes.self) { context in
            FocusActivityView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(.clear)
                .activitySystemActionForegroundColor(.white)
                .widgetURL(URL(string: context.attributes.isEvent ? "haloday://day" : "haloday://focus"))
        } dynamicIsland: { context in
            let glow = OrbitPalette.ritualColor(sky: FocusActivityView.sky(for: context.attributes, at: context.attributes.startDate))
            let running = context.state.pausedRemaining == nil && context.state.phase != "finished"
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    FocusActivityRing(attributes: context.attributes, state: context.state, now: nil, glow: glow)
                        .frame(width: 44, height: 44)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    FocusActivityTimer(attributes: context.attributes, state: context.state)
                        .font(DS.Typeface.clock(30))
                        .monospacedDigit()
                        .frame(maxWidth: 110)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.title).font(DS.Typeface.title(16, relativeTo: .headline)).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        if !context.attributes.isEvent && context.state.phase != "finished" {
                            Button(intent: PauseFocusIntent()) {
                                Label(running ? "Pause" : "Resume", systemImage: running ? "pause.fill" : "play.fill")
                            }
                            Spacer()
                            Button(intent: EndFocusIntent()) { Label("End", systemImage: "stop.fill") }
                        } else {
                            Link(destination: URL(string: "haloday://day")!) { Label("Open Halo Day", systemImage: "arrow.up.right") }
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                    .tint(glow)
                }
            } compactLeading: {
                FocusActivityRing(attributes: context.attributes, state: context.state, now: nil, glow: glow)
                    .frame(width: 22, height: 22)
            } compactTrailing: {
                FocusActivityTimer(attributes: context.attributes, state: context.state)
                    .font(.caption2.monospacedDigit())
                    .frame(width: 48)
            } minimal: {
                FocusActivityRing(attributes: context.attributes, state: context.state, now: nil, glow: glow)
                    .frame(width: 22, height: 22)
            }
            .keylineTint(glow)
            .widgetURL(URL(string: context.attributes.isEvent ? "haloday://day" : "haloday://focus"))
        }
    }
}
