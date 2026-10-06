# Halo Day UI review set

The PNGs are UI-test captures from an iPhone 17 Pro simulator (iOS 26.4), using a deterministic fixture date of 2026-10-05 at 10:05. The status bar is also pinned to 10:05.

The 54-image matrix covers Today, Calendar (Month), Widget Studio, Rituals, Focus, Settings, Themes, Paywall, and Onboarding in English and Vietnamese, paired with Pearl Halo light, Ruby Glass dark, and Midnight Gold dark. Filenames use `<language>-<theme>-<screen>.png`.

Run `scripts/screenshots.sh` to regenerate the set. It builds and runs the `testScreenshotMatrix` UI test, then exports its screenshots. Three motion recordings live alongside the images: `onboarding.mp4`, `studio-theme-type.mp4`, and `ritual-complete.mp4`; regenerate them with `scripts/record_ui_motion.sh`.
