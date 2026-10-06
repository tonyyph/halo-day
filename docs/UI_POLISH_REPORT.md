# Halo Day UI rebuild — verification report

## Phase summary

- Foundation: resolved theme palettes, Dynamic Type typography tokens, motion and accessibility-aware animation, haptics, reduced-transparency glass fallbacks, and corrected scheme-aware tint.
- Component library: mesh backgrounds, glass cards, branded controls, segmented/chip selectors, progress rings, rolling numbers, ritual completion, agenda/calendar pieces, phone/widget mockups, toast and shimmer components.
- Navigation and screens: animated tab changes and zoom sources; redesigned Today, Calendar, Studio, Themes, Rituals, Focus, Paywall, Onboarding, and Settings.
- Widgets and Live Activities: shared theme-aware widget layouts, interactive ritual affordances, styled Lock/Home Screen families, and Focus Live Activity presentation.
- Verification polish: deterministic launch fixtures, English/Vietnamese screenshot matrix, motion-recording test flows, calendar month weekday alignment, and reliable all-ritual completion feedback.

The implementation was committed in small phase commits on `ui/v1-polish`; this report and its verification artifacts accompany the final verification/fix commit.

## Verification

- Full command passed on iPhone 17 Pro / iOS 26.4 simulator: `xcodebuild -project HaloDay.xcodeproj -scheme HaloDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO test` — 6 unit tests and 7 UI tests passed.
- App and WidgetKit targets built successfully on iPhone SE (3rd generation) / iOS 18.1 simulator.
- Screenshot matrix: 54 captures at 1206 × 2622 in [`screenshots/`](screenshots/), produced by [`scripts/screenshots.sh`](../scripts/screenshots.sh). The fixed reference date is October 5, 2026 at 10:05; the simulator status bar is pinned to 10:05.
- Motion recordings: [onboarding](screenshots/onboarding.mp4), [Studio theme/type switching](screenshots/studio-theme-type.mp4), and [final ritual completion](screenshots/ritual-complete.mp4), produced by [`scripts/record_ui_motion.sh`](../scripts/record_ui_motion.sh).
- Reviewed all 54 captures in contact sheets, then inspected full-resolution samples across screens, themes, appearances, and languages. Calendar Month has locale-aligned weekday headers and October 5 selection; the Vietnamese “day streak” copy is translated, and no clipping or overflow was found in the reviewed set. Scrollable content continues beneath the translucent floating system tab bar, as expected.
- Source checks: `Color(hex:)` only appears in the palette resolver; `.easeInOut(duration:)` only appears in motion tokens; Focus contains no periodic one-second `TimelineView`; no `model.haptic()` calls remain.

## Instruments limitation

No hitch count is reported. On the oldest installed runtime (iOS 18.1), `xctrace` returned “Hitches is not supported on this platform” for Animation Hitches and “The SwiftUI instrument is not supported on the Simulator” for SwiftUI. Animation Hitches also returned the same unsupported-platform error on iOS 26.4. The only listed physical iPhone is offline, so the requested four-scenario Instruments measurements could not be captured. Connect a supported physical iPhone and repeat the SwiftUI/Animation Hitches pass for Today scrolling, Calendar Month paging, Studio scrolling, and theme switching before making any zero-hitch claim.

## Non-UI changes and rationale

- Added a DEBUG screenshot launch configuration that supplies deterministic theme/date/event/habit fixtures in memory, skips purchase/calendar refresh side effects, and leaves shared user data untouched. This exists only to make screenshot and UI test runs repeatable.
- Added the missing Vietnamese translation for “day streak” and regenerated the localization catalog with the repository scripts.
- Calendar’s selectable Month grid now displays localized weekday headers aligned to the locale’s first weekday.
- Ritual completion detection is performed in the user action that changes the habit, so the last completion can synchronously trigger the celebratory state, toast, and success haptic.
- UI tests now verify screenshot localization/theme coverage, the actual Month grid, onboarding progression, Studio selection, and final-ritual completion. No domain model, EventKit/notification service, storage contract, StoreKit behavior, ActivityKit state, or widget timeline logic was changed in this pass.

## Platform gates and follow-ups

- Minimum deployment target is iOS 18.0. The iOS 26 `.glassEffect` treatment is availability-gated; iOS 18 uses material and palette fallbacks.
- StoreKit products must be configured in App Store Connect before purchases/prices become live. The current empty-catalog state is explicitly identified as unconfigured and does not claim a trial or price.
- Habit time-of-day/scheduling metadata and per-slot widget layouts are not represented in the current models, so those remain UI-level/generalized rather than persisted domain features.
- Widget and Live Activity appearance must still be checked on real Lock Screens and Dynamic Island devices; iOS does not permit an app to customize the entire Lock Screen.
- Simulator screenshots/recordings are visual QA artifacts, not App Store marketing screenshots. Final App Store assets need device capture and product/legal copy review.
