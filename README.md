# Halo Day

Your day as a ring of light, under the real sky. Halo Day is a native SwiftUI planner for iOS 18+ that draws your calendar, rituals and focus on one 24-hour ring, the **Orbit**, over a backdrop that follows the sun where you are. It has Lock Screen and Home Screen widgets, a focus Live Activity, and wallpapers made from the same sky.

The v2 design lives in [docs/superpowers/specs/2026-10-06-halo-day-v2-redesign-design.md](docs/superpowers/specs/2026-10-06-halo-day-v2-redesign-design.md). The original v1 product scope is in [docs/SPEC.md](docs/SPEC.md).

## What's in the app

- **Day.** The Orbit dial shows noon at the top, the night as a shaded arc, events as arcs in up to three lanes, and rituals as beads. A Light Column lists what's next. Pinch or use the scale bar to zoom out to a week strip and a month grid.
- **Studio.** Lock Screen setups with up to four widget slots, following iOS's slot rules. You can save sky wallpapers to Photos (add-only), share a card, and read a guide to placing widgets.
- **You.** A week recap, focus history, rituals with streaks, countdowns, the sky picker and Settings.
- **Focus.** A dusk-tinted timer. With Premium, the focus timer and event countdowns appear as Live Activities on the Lock Screen and in the Dynamic Island.
- **Skies.**
  - Living Sky (free) follows the real sun and becomes Celestial at night.
  - Premium adds Instrument, Aurora, Golden Hour and Mist.
  - Location is optional and rounded to about 10 km. Without it, the sky uses your time zone.
- **Widgets.** Six kinds: Orbit, Next up, Rhythm, Rituals, Countdown and Month. They work on the Lock Screen, the Home Screen and in StandBy, and use light ink when iOS removes the background.
- **Languages.** English and Vietnamese.

## Open and run

1. Open `HaloDay.xcodeproj` in Xcode 26.4 or newer and select the `HaloDay` scheme.
2. Run on an iPhone Simulator. Onboarding works without Calendar permission, using sample events that are labelled as samples.
3. To run on a physical iPhone:
   - Set your team on both `HaloDay` and `HaloDayWidgets`.
   - Register `group.co.haloday.shared` for both `co.haloday.app` and `co.haloday.app.widgets`.
   - Enable App Groups in both signing profiles.
4. `HaloDay.storekit` is selected in the shared scheme for local purchase testing. Production products use the IDs in `PurchaseService.swift`.

## Test and capture

| Command | What it does |
| --- | --- |
| `xcodebuild -project HaloDay.xcodeproj -scheme HaloDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO test` | Runs the unit and UI tests. |
| `bash scripts/screenshots.sh` | Writes 74 fixture screenshots to `docs/screenshots/v2/day`: 3 skies × 2 languages × the main screens, plus onboarding, paywall, guide and AX3 text-size captures. |
| `bash scripts/widget_gallery.sh en` / `vi` | Renders every widget kind and family, plus StandBy, SE, empty and locked variants, to `docs/screenshots/v2/widgets/<lang>`. |
| `bash scripts/record_ui_motion.sh` | Records the motion journeys. |
| `swift scripts/generate_icon.swift HaloDayApp/Resources/Assets.xcassets/AppIcon.appiconset` | Regenerates the light, dark and tinted app icons. |

How fixture mode works:

- Fixture mode is enabled with `-UITestScreenshotMode`.
- It takes these launch arguments: `-UITestTime HH:MM`, `-UITestScreen day|week|month|focus|studio|you|rituals|onboarding|paywall`, and `-UITestTheme`.
- It never writes to storage.

When you add or remove files, run `ruby scripts/generate_project.rb`; it needs the `xcodeproj` gem.

To change copy:

1. Add the Vietnamese strings to `scripts/vi_translations.json`.
2. Run `ruby scripts/generate_localizations.rb`.
3. Run `ruby scripts/apply_vi_localization.rb`.

## Project layout

- `HaloDayApp/App`: entry point, the three tabs (Day, Studio, You), deep links and launch fixtures.
- `HaloDayApp/Screens`: Day (Orbit, Light Column, zoom), Studio, You, FocusMode, Onboarding, Paywall and Settings.
- `HaloDayApp/ViewModels/HaloModel.swift`: the observable app state and its operations.
- `HaloDayApp/Services`: EventKit, notifications, StoreKit 2, ActivityKit, location, Photos and art rendering.
- `Shared/Sky`: the NOAA solar calculator, sky keyframes and the `SkyEngine`, which enforces legibility (4.5:1 for primary and secondary ink).
- `Shared/Orbit`: the geometry and the single `OrbitCanvas` renderer, shared by the app, the widgets and the Live Activity.
- `Shared/Widgets`: widget data, timelines, and the accessory, Home and Live Activity views.
- `HaloDayWidgets`: the widget bundle, the setup intent and the focus Live Activity.

## Platform behavior

- **Widget placement.** The app cannot place or recolor Lock Screen widgets. Studio previews them, and iOS applies the vibrant tint.
- **Data and refresh.**
  - Widget data is a local App Group snapshot; no calendar data leaves the device.
  - Timelines tick at event boundaries, every five minutes in the 90 minutes before an event, and hourly for sky-backed families.
- **Purchases.** Prices, periods and trials come only from StoreKit. When StoreKit returns no products, the paywall shows placeholders and disables purchase.

The release status of each item is tracked in [docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md).
