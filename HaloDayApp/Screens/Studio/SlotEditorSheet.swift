import SwiftUI

/// Choose what goes in one Lock Screen slot, within iOS's slot rules.
struct SlotEditorSheet: View {
    @Environment(HaloModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.haloScreenshotMode) private var fixture
    var target: SlotTarget
    @State private var lockedChoice = false

    var body: some View {
        NavigationStack {
            SkyScreen { sky, _ in
                if let setup = model.setups.first(where: { $0.id == target.setupID }) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: DS.Space.l) {
                            Text(title).font(DS.Typeface.display(26, relativeTo: .title))
                            Text(note(setup)).font(.footnote).opacity(SkyEngine.secondaryOpacity)
                            ForEach(kinds(for: setup)) { kind in
                                let selected = current(setup)?.kind == kind
                                Button { choose(kind, in: setup) } label: {
                                    HStack(spacing: DS.Space.m) {
                                        Image(systemName: kind.symbol).frame(width: 32)
                                        Text(kind.title).font(.body.weight(.medium))
                                        Spacer()
                                        if kind.isPremium && !model.purchases.isPremium { Image(systemName: "lock.fill").font(.footnote) }
                                        if selected { Image(systemName: "checkmark") }
                                    }
                                    .padding(DS.Space.m)
                                    .frame(minHeight: 44)
                                    .haloGlass(RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous), tint: sky.mid.color)
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
                                .accessibilityIdentifier("kind-\(kind.rawValue)")
                            }
                            if lockedChoice {
                                VStack(alignment: .leading, spacing: DS.Space.s) {
                                    Text("Rhythm and Rituals widgets come with Premium.")
                                    Button("See Premium") { dismiss(); model.showPaywall = true }
                                        .buttonStyle(GlassPillStyle(sky: sky))
                                        .accessibilityIdentifier("slot-premium")
                                }
                            }
                            if target.position != .add, current(setup) != nil || target.position == .inline && setup.inline != nil {
                                Button(role: .destructive) { remove(from: setup) } label: { Label("Remove", systemImage: "minus.circle").frame(maxWidth: .infinity) }
                                    .buttonStyle(GlassPillStyle(sky: sky))
                                    .accessibilityIdentifier("slot-remove")
                            }
                        }
                        .padding(DS.Space.xl)
                    }
                }
            }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }

    private var title: String {
        switch target.position {
        case .inline: String(localized: "Above the clock")
        case .slot: String(localized: "This widget")
        case .add: String(localized: "Add a widget")
        }
    }

    private func note(_ setup: LockSetup) -> String {
        switch target.position {
        case .inline: String(localized: "One line of text sits above the clock.")
        default: String(localized: "Below the clock: up to four small circles, or two wide widgets, or a mix. \(setup.remainingUnits) of 4 free.")
        }
    }

    private func current(_ setup: LockSetup) -> LockSlot? {
        if case let .slot(index) = target.position, setup.slots.indices.contains(index) { return setup.slots[index] }
        if case .inline = target.position, let inline = setup.inline { return LockSlot(kind: inline, family: .inline) }
        return nil
    }

    /// Families this kind could take here without breaking the four-unit row.
    private func families(_ kind: WidgetKind, in setup: LockSetup) -> [AccessoryFamily] {
        switch target.position {
        case .inline: return kind.families.filter { $0 == .inline }
        case let .slot(index):
            let freed = setup.slots.indices.contains(index) ? setup.slots[index].family.units : 0
            return kind.families.filter { $0 != .inline && $0.units <= setup.remainingUnits + freed }
        case .add: return kind.families.filter { $0 != .inline && $0.units <= setup.remainingUnits }
        }
    }

    private func kinds(for setup: LockSetup) -> [WidgetKind] { WidgetKind.allCases.filter { !families($0, in: setup).isEmpty } }

    private func choose(_ kind: WidgetKind, in setup: LockSetup) {
        guard !kind.isPremium || model.purchases.isPremium else { lockedChoice = true; return }
        var updated = setup
        let options = families(kind, in: setup)
        switch target.position {
        case .inline:
            updated.inline = kind
        case let .slot(index):
            guard updated.slots.indices.contains(index) else { return }
            let keep = updated.slots[index].family
            updated.slots[index] = LockSlot(id: updated.slots[index].id, kind: kind, family: options.contains(keep) ? keep : options[0])
        case .add:
            updated.slots.append(LockSlot(kind: kind, family: options.contains(.circular) ? .circular : options[0]))
        }
        if HaloViewActions.saveSetup(updated, model: model, fixture: fixture) { dismiss() }
    }

    private func remove(from setup: LockSetup) {
        var updated = setup
        switch target.position {
        case .inline: updated.inline = nil
        case let .slot(index): if updated.slots.indices.contains(index) { updated.slots.remove(at: index) }
        case .add: return
        }
        if HaloViewActions.saveSetup(updated, model: model, fixture: fixture) { dismiss() }
    }
}
