# Halo Day v2 release checklist

This is spec §11, with the status as of 2026-10-07. Each item is marked with one of three statuses:

- ✅ Verified in the simulator.
- 📱 Needs a physical device.
- 🏪 Needs App Store Connect or a signed build.

| # | Item | Status | Evidence / what remains |
| --- | --- | --- | --- |
| 1 | Full `xcodebuild … test` passes on the iPhone 17 Pro (iOS 26), and the app builds for the iPhone SE (3rd generation) on iOS 18 | ✅ | Unit and UI suites, plus an SE simulator build (`arch=arm64`). |
| 2 | A reviewer has looked at the screenshot matrix and the motion videos | ✅ screenshots · 📱 motion | The screenshot sets are in `docs/screenshots/v2/day` (74) and `docs/screenshots/v2/widgets/{en,vi}` (77 each). Motion still needs `scripts/record_ui_motion.sh` and a human review. |
| 3 | No untranslated strings (en/vi) | ✅ | Every key in the string catalog has a Vietnamese value. Terminology is unified: "nghi thức" for rituals and "Premium". The vi screenshots were reviewed. |
| 4 | The final icon is in place and the launch screen uses the sky | ✅ | `scripts/generate_icon.swift` produces light, dark and tinted icons. The launch screen uses the `LaunchSky` colour, which has a dark variant. |
| 5 | The privacy manifest is up to date | ✅ | There is no tracking and no collected data types. Location is rounded to about 10 km and never leaves the device. Photos access is add-only (`NSPhotoLibraryAddUsageDescription`). No required-reason APIs are used; UserDefaults and file timestamps were checked. |
| 6 | The StoreKit products exist in App Store Connect, and a purchase and a restore were tested on a signed build | 🏪 | Create `co.haloday.premium.monthly`, `.yearly` and `.lifetime` in App Store Connect. Test a purchase, a cancellation, a pending purchase (Ask to Buy) and a restore on a signed TestFlight build. |
| 7 | The App Group, widgets and Live Activity were checked on a device with a Dynamic Island and on one without | 📱 | Check that the setup chosen in each widget is honoured, that ending focus from the Island records the session in history, StandBy legibility, and the 15-minute dismissal after focus ends. |
| 8 | Instruments (Hitches/SwiftUI) was run on a device for Day scrolling, zooming and changing the sky | 📱 | Profile on an iPhone 12-class device and on a current one. |

## App Store

- **Screenshots.** Use the Living Sky and Celestial captures from `docs/screenshots/v2/day` for Day, Week and Month, and add Studio, Focus and the widget gallery. The App Store needs 6.9" and 6.5" sets.
- **Subtitle.** "Your day, as a ring of light." / "Ngày của bạn, như một vòng sáng."
- **Privacy label.** Data Not Collected.
- **Before submission.**
  - Replace the bundle identifiers if they are taken.
  - Set the team and App Group.
  - Confirm the Terms (Apple standard EULA) and Privacy texts.
