import SwiftUI

struct TodayProgressHero: View {
    @Environment(HaloModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.haloReferenceDate) private var referenceDate
    @Environment(\.dynamicTypeSize) private var dynamicType

    var body: some View {
        if let referenceDate { hero(at: referenceDate) }
        else {
            TimelineView(.periodic(from: .now, by: 60)) { context in hero(at: context.date) }
        }
    }

    private func hero(at date: Date) -> some View {
        let progress = model.progress(at: date)
        let done = model.completedHabits(on: date)
        let layout = dynamicType.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 20)) : AnyLayout(HStackLayout(spacing: 24))
        return layout {
            ProgressRing(progress: progress)
                .frame(width: 120, height: 120)
                .overlay {
                    Text(progress, format: .percent.precision(.fractionLength(0)))
                        .haloFont(.numericL).monospacedDigit().contentTransition(.numericText())
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                }
            VStack(alignment: .leading, spacing: 8) {
                Text("Day progress").captionUpper().foregroundStyle(palette.ink2).accessibilityLabel("Day progress")
                Text("\(done) of \(model.habits.count) rituals kept")
                    .haloFont(.displayS).fixedSize(horizontal: false, vertical: true)
                Text("Your day, beautifully on display.").haloFont(.footnote).foregroundStyle(palette.ink2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }
}

#Preview("Progress hero · Pearl") {
    DesignPreview { TodayProgressHero().environment(HaloModel()) }
}

#Preview("Progress hero · Gold AX3") {
    DesignPreview(themeID: "midnightGold", scheme: .dark, accessibility: true, reduceMotion: true) {
        TodayProgressHero().environment(HaloModel())
    }
}
