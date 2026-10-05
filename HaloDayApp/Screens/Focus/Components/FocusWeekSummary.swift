import SwiftUI
import Charts

struct FocusWeekSummary: View {
    private struct Day: Identifiable {
        let date: Date
        let minutes: Int
        var id: Date { date }
    }
    private let days: [Day]
    private let total: Int
    private let maximum: Int
    @Environment(\.palette) private var palette
    @Environment(\.haloReduceMotion) private var reduceMotion
    @State private var appeared = false

    init(history: [FocusSession], date: Date = .now) {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: date)!.start
        days = (0..<7).map { offset in
            let day = calendar.date(byAdding: .day, value: offset, to: start)!
            let value = history.filter { calendar.isDate($0.startDate, inSameDayAs: day) }
                .reduce(0) { $0 + $1.durationMinutes }
            return Day(date: day, minutes: value)
        }
        total = days.reduce(0) { $0 + $1.minutes }
        maximum = max(5, days.map(\.minutes).max() ?? 5)
    }

    var body: some View {
        HaloCard(variant: .inset) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text("This week").haloFont(.displayS)
                    Spacer()
                    RollingNumber(value: total).haloFont(.numericM)
                    Text("min").haloFont(.footnote).foregroundStyle(palette.ink2)
                }
                Chart(days) { day in
                    BarMark(
                        x: .value(String(localized: "Day"), day.date, unit: .day),
                        y: .value(String(localized: "Minutes"), reduceMotion || appeared ? day.minutes : 0)
                    )
                    .foregroundStyle(palette.accent)
                    .cornerRadius(4)
                }
                .chartYScale(domain: 0...maximum)
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks(values: days.map(\.date)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow))
                    }
                }
                .frame(height: 105)
                .animation(reduceMotion ? nil : Motion.smooth, value: appeared)
                .accessibilityLabel("Focus history")
                .accessibilityValue(Text("\(total) min"))
            }
        }
        .onAppear { appeared = true }
    }
}

#Preview("Focus week · Pearl") {
    DesignPreview { FocusWeekSummary(history: []) }
}

#Preview("Focus week · Gold AX3") {
    DesignPreview(themeID: "midnightGold", scheme: .dark, accessibility: true, reduceMotion: true) {
        FocusWeekSummary(history: [])
    }
}
