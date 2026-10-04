# Halo Day

Native SwiftUI planner for iOS 18+, with Lock Screen and Home Screen widgets, focus Live Activities, calendar reading, rituals, eight visual themes, and a local StoreKit test catalog. Product direction and the larger v1 scope live in [docs/SPEC.md](docs/SPEC.md).

## Open and run

1. Open `HaloDay.xcodeproj` in Xcode 26.4 or newer and select the `HaloDay` scheme.
2. Select an iPhone Simulator and run. The six-step onboarding works without Calendar permission using visibly labeled sample events.
3. For a physical iPhone, set your Apple Developer team on both `HaloDay` and `HaloDayWidgets`, register the `group.co.haloday.shared` App Group for both identifiers, and enable App Groups in the signing profiles. The project uses `co.haloday.app` and `co.haloday.app.widgets`; change these before shipping if the identifiers are taken.
4. In the scheme’s Run options, select `HaloDay.storekit` for local purchase testing. The project carries this setting in its shared scheme. Real products must later be created in App Store Connect with the IDs in `PurchaseService.swift`.

`xcodebuild -project HaloDay.xcodeproj -scheme HaloDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO test` runs the unit and UI tests without a signing team. Signed builds are needed to verify App Group sharing and Live Activities end to end.

## Project layout

- `HaloDayApp/App` — entry point, tab routing and sheet presentation.
- `HaloDayApp/Screens` — onboarding and the five main tabs, with theme gallery, settings and paywall.
- `HaloDayApp/ViewModels` — `HaloModel`, the observable app state and operations.
- `HaloDayApp/Services` — EventKit, notifications, StoreKit 2 and ActivityKit.
- `HaloDayWidgets` — eight configurable widget kinds and Focus/Countdown Live Activity views.
- `Shared` — Codable models, theme tokens, renderer, mock data, storage and AppIntents compiled into the app and extension. This is the shared-source equivalent of the spec’s proposed local `HaloKit` package. It keeps one widget renderer and one set of models for both targets.
- `HaloDayTests`, `HaloDayUITests` — core rules, palette contrast, StoreKit catalog and user journeys.

## Platform behavior

The app cannot install or recolor Lock Screen widgets itself. Studio previews accessory layouts in monochrome; iOS controls their vibrant tint. Full theme color appears in the app, Home Screen widgets and Live Activities. Widget data is a local App Group JSON snapshot written by the app; no calendar data is sent to a server. Event changes are observed while the app runs or returns to the foreground. Widgets use precomputed timeline boundaries and cannot guarantee an instant refresh while the app is suspended.

The free focus timer works in-app and schedules a local end reminder when notifications are allowed. Premium focus uses ActivityKit where Live Activities are enabled. Event countdown Live Activities are started manually from an event in the hour before it begins. The paywall remains usable when StoreKit returns no products; it shows plan placeholders and disables purchase until prices load. Product retrieval and purchases still need a signed StoreKit test run before release.

## MVP limits and release work

This project implements the requested buildable MVP. The broader spec also calls for wallpaper packs and Photos saving, scheduled morning briefs and ritual reminders, event countdown background starts, more detailed widget slot editing, focus history polish, a seven-day introductory trial, and full accessibility/rendering matrix verification. Those require another pass. The icon is generated placeholder artwork. Pricing shown in the local StoreKit catalog is for testing; production price and terms must come from App Store Connect. No trial is promised in the current UI because it is not configured. The bundle ID, legal URLs, final artwork, and signed device behavior require release setup.

After editing Swift files, the checked-in Xcode project works directly. If files are added, run `ruby scripts/generate_project.rb` with a Ruby that has the `xcodeproj` gem. `ruby scripts/generate_localizations.rb` rebuilds the English string catalog after copy changes; review newly extracted keys before localization.
