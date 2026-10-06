import SwiftUI

/// Every sky as a living tile, each drawn at this minute in its own light.
struct SkyPickerView: View {
    @Environment(HaloModel.self) private var model
    @Environment(\.haloReferenceDate) private var referenceDate
    @Environment(\.haloScreenshotMode) private var fixture

    var body: some View {
        SkyScreen { _, now in
            ScrollView {
                VStack(spacing: DS.Space.m) {
                    ForEach(SkyID.allCases) { sky in tile(sky, now: now) }
                }
                .padding(DS.Space.l)
            }
        }
        .navigationTitle("Skies")
    }

    private func tile(_ sky: SkyID, now: Date) -> some View {
        let state = SkyEngine.state(sky: sky, at: now, coordinate: model.skyCoordinate)
        let selected = model.settings.skyID == sky
        let locked = sky.isPremium && !model.purchases.isPremium
        let calendar = Calendar.current
        return Button { HaloViewActions.applySky(sky, model: model, fixture: fixture) } label: {
            ZStack(alignment: .leading) {
                SkyBackground(state: state)
                OrbitCanvas(content: OrbitContent(layout: OrbitLayout(day: now, events: [], calendar: calendar),
                                                  nowHour: OrbitGeometry.hours(of: now, calendar: calendar)),
                            sky: state, style: sky.orbitStyle)
                    .frame(width: 104, height: 104)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, DS.Space.s)
                VStack(alignment: .leading, spacing: DS.Space.xs) {
                    HStack(spacing: DS.Space.s) {
                        Text(sky.title).font(DS.Typeface.title(22, relativeTo: .title3))
                        if locked { Image(systemName: "lock.fill").font(.footnote).accessibilityLabel(Text("Premium")) }
                        if selected { Image(systemName: "checkmark.circle.fill").accessibilityHidden(true) }
                    }
                    Text(sky.mood).font(.footnote).opacity(SkyEngine.secondaryOpacity)
                }
                .foregroundStyle(state.inkColor.color)
                .padding(DS.Space.l)
                .padding(.trailing, 100)
            }
            .frame(height: 128)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.glass, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.glass, style: .continuous).strokeBorder(Color.primary.opacity(selected ? 0.5 : 0.12), lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("sky-\(sky.rawValue)")
    }
}

/// Open-source notices for bundled fonts.
struct LicensesView: View {
    private var license: String {
        Bundle.main.url(forResource: "OFL", withExtension: "txt").flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.m) {
                Text(verbatim: "Fraunces").font(.headline)
                Text(verbatim: license).font(.footnote.monospaced())
            }
            .padding(DS.Space.l)
        }
        .navigationTitle("Licenses")
    }
}
