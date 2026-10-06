# Halo Day v2 · Phase 6 (Widgets & Live Activity) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the eight v1 widget kinds with the six v2 kinds (Orbit, Next up, Rhythm, Rituals, Countdown, Month) across Lock Screen, Home Screen and StandBy, all drawn by the shared v2 renderers, and redesign the Focus/Countdown Live Activity around the Orbit ring and the focus-dusk sky.

**Architecture:** `WidgetTimeline` (Shared, pure) computes entry dates; `WidgetSnapshot` (Shared) loads a `WidgetData` + active `LockSetup` + premium flag from App Group storage. Lock Screen families render `AccessoryView` (Phase 5); Home/StandBy families render new `HomeWidgetView`s over `SkyBackground` for the entry's minute. One `Widget` struct per kind uses an `AppIntentConfiguration` whose optional `SetupEntity` picks a setup (else the active one) — the setup's sky colours Home widgets. The Live Activity view is a plain Shared view (`FocusActivityView`) so it can be rendered in tests. A unit-test "gallery" renders every kind × family to PNG attachments, exported for visual review.

**Tech Stack:** WidgetKit, ActivityKit, AppIntents, SwiftUI, XCTest.

**Spec:** `docs/superpowers/specs/2026-10-06-halo-day-v2-redesign-design.md` (§5, §4.3, §9), v1 constraints `docs/SPEC.md` §1.4.

## Global Constraints

Same as earlier phases. Widget reloads only on data changes; timelines precompute event boundaries plus at most one entry per hour for sky backgrounds. Lock Screen content stays single-ink (vibrant). Live Activity payload unchanged in size (< 4 KB). Premium kinds: Rhythm and Rituals show a locked placeholder for free users.

## Review Focus

1. **Empty data** (no calendar permission, no events, no habits, no countdown) renders a meaningful state in every kind/family — gallery covers it.
2. **Timeline boundaries**: events crossing midnight, focus ending mid-day, DST days; never more than ~30 entries a day — Task 1 tests.
3. **Deep links** from each widget land on the v2 tab (`haloday://day`, `event/<id>`, `you`, `calendar`) — Task 3 test of `WidgetKind.url(for:)`.
4. **Interactive rituals** (`ToggleRitualIntent`) update storage and reload timelines without the app; the app reflects it on foreground.
5. **Live Activity** paused/finished/event states and devices without a Dynamic Island.

---

### Task 1: Widget timeline and snapshot

**Files:** Create `Shared/Widgets/WidgetTimeline.swift`; Test `HaloDayTests/WidgetTimelineTests.swift`

**Interfaces — Produces:** `enum WidgetTimeline { static func entryDates(now:events:focus:hourly:calendar:) -> [Date] }` — sorted unique dates: now, start/end of today's events after now and before midnight, the focus end if running, every hour on the hour when `hourly`, and midnight; `struct WidgetSnapshot { var data: WidgetData; var setup: LockSetup; var isPremium: Bool; static func load(storage:date:setupID:) -> WidgetSnapshot }` (sample events when no permission, active/first/starter setup); `extension WidgetKind { func url(for data: WidgetData) -> URL }` (orbit/rhythm → `haloday://day`, nextUp → `haloday://event/<id>` or day, rituals → `haloday://day`, countdown → `haloday://you`, month → `haloday://calendar`).

- [ ] **Step 1: failing tests** — boundaries (events 9–9.5, 10.5–11.25, 23–01 tomorrow; now 10.08 → contains 10.5, 11.25, 23:00 and midnight, not 9.5 or tomorrow's 01:00), focus end included only while running, hourly adds 13 or 14 hourly dates, count ≤ 40, snapshot falls back to the starter setup and sample events, URLs per kind.
- [ ] **Step 2:** implement; PASS; commit `feat(widgets): timeline dates, snapshot loading and widget deep links`.

### Task 2: Home Screen and StandBy views

**Files:** Create `Shared/Widgets/HomeWidgetViews.swift`; Test `HaloDayTests/WidgetGalleryTests.swift`

**Interfaces — Produces:** `enum HomeFamily: CaseIterable { small, medium, large }` with `size` (158×158, 338×158, 338×354 pt); `WidgetKind.homeFamilies` (orbit: small, large · nextUp: small · rhythm: medium, large · rituals: small, medium · countdown: small · month: medium); `struct HomeWidgetView: View { kind; family; data; sky: SkyState; style: OrbitStyle; locked: Bool }` (draws content only — the extension supplies `containerBackground` with `SkyBackground`; tests wrap it in one).

Designs (ink from the sky, Fraunces titles, glass-free — widgets are flat):
- **Orbit small**: the Orbit (OrbitCanvas, no breathing) filling the widget with the moment name under it; **large**: Orbit top, date in Fraunces, next three events below.
- **Next up small**: badge ("In 25 min"/"Now"), title (2 lines), time range, location; empty: "A clear day."
- **Rhythm medium**: a mini Orbit left, four rows right; **large**: date header, Orbit, up to seven rows.
- **Rituals small**: ritual ring + "2/3" + three bead buttons; **medium**: up to four rows of bead + title + check button. Buttons are `Button(intent: ToggleRitualIntent(ritualID:))` when interactive (extension), plain when rendered in tests.
- **Countdown small**: big day count, title, date, ring.
- **Month medium**: month name + progress, and the month as `MiniOrbit` rings (5–6 rows of 7, 16 pt).
- **Locked** (premium kind, free): blurred content + "Unlock in Halo Day".

- [ ] **Step 1: failing gallery test** — for every kind × home family × {Living Sky 10:05, Celestial 22:30} and every kind × accessory family (vibrant, on a dark sky), render with `ImageRenderer` (scale 3), assert visible pixels, and attach PNGs named `widget-<kind>-<family>-<sky>`; plus the empty-data variant for each.
- [ ] **Step 2:** implement; PASS; commit `feat(widgets): v2 Home Screen and StandBy widget views`.

### Task 3: Widget extension

**Files:** Rewrite `HaloDayWidgets/LockScreenWidgets/HaloWidgets.swift`; Modify `Shared/Extensions/HaloIntents.swift` (keep intents; `EndFocusIntent` also appends the session to `focusHistory`); Test `HaloDayTests/WidgetTimelineTests.swift` (URL cases)

- `SetupEntity`/`SetupQuery` over `AppGroupStorage.setups`; `HaloSetupIntent: WidgetConfigurationIntent` ("Setup", optional).
- `HaloEntry { date, snapshot }`; `HaloProvider(kind:)` builds entries from `WidgetTimeline.entryDates` (hourly for Home families) and `WidgetSnapshot.load`; reload policy `.after(midnight)`; placeholder/snapshot use sample data.
- `HaloKindWidget(kind:)` → `AppIntentConfiguration(kind: "Halo.v2.\(kind.rawValue)")`, display name `kind.title`, description per kind, supported families = accessory families + home families (+ `.systemSmall`/`.systemLarge` appear in StandBy automatically).
- Entry view: accessory families → `AccessoryView(kind:family:data:tint:nil)` with `.containerBackground(for: .widget) { Color.clear }` and `.widgetAccentable()` on primary marks; home families → `HomeWidgetView` with `.containerBackground(for: .widget) { SkyBackground(state: SkyEngine.state(sky: setup.skyID, at: entry.date, coordinate: TimeZoneLocator…/settings)) }`; `.widgetURL(kind.url(for: data))`; locked when `kind.isPremium && !premium`.
- `WidgetBundle`: the six kinds + `HaloFocusLiveActivity`.
- Remove `PresetEntity`, `PresetQuery`, `HaloConfigurationIntent`, `HaloTimelineProvider`, `HaloWidgetView`, `HaloPlannerWidget`.
- [ ] Build the app (embeds the extension) for iPhone 17 Pro and iPhone SE (iOS 18.1); unit suite green; commit `feat(widgets): six v2 widget kinds in the extension`.

### Task 4: Live Activity

**Files:** Create `Shared/Widgets/FocusActivityView.swift`; Rewrite `HaloDayWidgets/LiveActivities/HaloFocusLiveActivity.swift`; Modify `HaloDayApp/Services/LiveActivityService.swift` (pass `model.settings.skyID.rawValue` as `themeId`), `HaloDayApp/ViewModels/HaloModel.swift` call sites; Test gallery additions.

- `FocusActivityView(attributes:, state:)` — Lock Screen banner over `SkyEngine.focusDusk` of the attributes' sky: a ring (`ProgressView(timerInterval:countsDown:)` circular, tinted with the dusk glow) on the left; title in Fraunces; `Text(timerInterval:)` large; "until 11:15"; paused → static remaining + "Paused"; finished → "Done · +25′"; event countdown → calendar glyph + "Starts at 10:30".
- Dynamic Island: compact leading = small ring progress, compact trailing = timer text; minimal = ring; expanded = ring (leading), timer (trailing), title (center), Pause/End buttons (bottom, intents) or "Open Halo Day" for events. `keylineTint` = dusk glow.
- [ ] Gallery renders `FocusActivityView` for running, paused, finished and event states (both skies); PASS; build; commit `feat(live-activity): Orbit ring Live Activity over the focus dusk`.

### Task 5: Gallery export and review

- [ ] Add `scripts/widget_gallery.sh` (runs `WidgetGalleryTests`, exports attachments to `docs/screenshots/v2/widgets/`); run; review every image (ink legibility on both skies, truncation, empty states, locked state, vi copy via a vi run), fix, re-run. Full suite + SE build green; commit `test(widgets): widget and Live Activity gallery`.
