# Codex Prompt: Halo Day UI & Motion Rebuild (v1.0 production polish)

> Paste everything below the line into Codex, run from the repo root `~/halo-day`.

---

You are a senior iOS engineer and motion designer working on **Halo Day**, a SwiftUI iOS app (iOS 18+, Xcode 26) in this repo. The app is functionally complete but the UI feels like an MVP: flat, repetitive, stock controls, and no motion. Your job is to **rebuild the presentation layer so it feels like a finished, premium, Apple-Design-Award-calibre product**: modern, fluid, and delightful, with animations that are both beautiful and cheap to render.

Read these first, in this order:
1. `docs/SPEC.md`: product and design source of truth (Sections 6 *Screens*, 7 *Visual Design System*, 8 *Themes*, 10–11 *Widgets / Live Activities*).
2. `Shared/Theme/ThemePalettes.swift`, `Shared/Theme/HaloComponents.swift`, `HaloDayApp/Components/ScreenLayout.swift`: the current design system.
3. Every file in `HaloDayApp/Screens/`, `Shared/Theme/WidgetContent.swift`, `HaloDayWidgets/`.

This prompt **overrides SPEC.md on visual and motion details** where they differ. SPEC.md still governs features, copy, and platform constraints.

## 0. Ground rules

- **Do not change behaviour or data.** `HaloModel`, `Services/`, `Shared/Models`, `Shared/Storage`, `HaloIntents`, StoreKit logic, and widget timeline logic stay functionally identical. You may add small view-facing helpers (computed properties, formatters) and fix bugs you find, but list every non-UI change in your final summary.
- **Preserve localization.** All user-facing strings stay localizable (`Localizable.xcstrings`, English + Vietnamese via `scripts/`). New strings must be added to the catalog. Run `ruby scripts/generate_localizations.rb` and the VI apply script, and make sure no Vietnamese string regresses or overflows (Vietnamese runs ~20–30% longer than English, so test it).
- **No third-party dependencies.** Pure SwiftUI + Apple frameworks.
- **Git hygiene:** the working tree has uncommitted changes. First commit them as-is (`chore: snapshot before UI rebuild`), then create branch `ui/v1-polish` and work there in small, reviewable commits per phase (Section 9).
- When you add files, regenerate the project with `ruby scripts/generate_project.rb`.
- Code style: **readable SwiftUI**. The current code crams entire views into single 300-character lines. Break views into small, named subviews (`private struct NextEventCard: View`), one modifier per line for anything non-trivial, and keep files under ~250 lines by splitting into `Screens/<Feature>/Components/`.

## 1. The quality bar

The target feel is somewhere between **Apple Weather, Apple Fitness, Things 3, Structured, and (Not Boring) Weather**: calm, editorial, tactile. Concretely:

- **Every state change animates.** Nothing ever pops or jumps. Numbers roll, rings sweep, lists re-flow, sheets morph from their source.
- **Hierarchy through contrast, not boxes.** Not everything is a card. Use whitespace, typographic scale, and grouping. Today currently wraps every ritual in its own card. Fix that pattern everywhere.
- **Custom controls where they define the brand** (duration dial, theme picker, chips, segmented, ritual check, plan picker). Use system controls where users expect them (Settings `Form`, `DatePicker`, alerts, share sheets).
- **Tactile.** Every meaningful interaction has a press state *and* a haptic.
- **60/120 fps.** No dropped frames on iPhone 12 during any animation or scroll. ProMotion should feel buttery.

## 2. Foundation fixes (do these first)

1. **Precompute colors.** `Color(hex:)` currently parses strings on every `body` evaluation, in every view. Introduce `struct ResolvedPalette { let bg, halo, surface, surfaceSunken, ink, ink2, ink3, hairline, accent, accentInk, accentOn, accentSoft, shadowTint: Color }`, cached once per theme × colorScheme (static dictionary or lazy property). Expose it via `@Environment(\.palette)` set at the root and updated when theme or scheme changes. Views must never call `Color(hex:)` directly. Add `ink3` (ink2 @ 60%) and `glassStroke`.
2. **Fix the tint bug:** `HaloDayApp.swift` sets `.tint(model.theme.light.accentInk)`, which is wrong in dark mode. Tint must come from the resolved palette for the current scheme.
3. **Typography tokens.** Replace the two `HaloTokens` fonts with the full scale from SPEC §7.2 as `enum HaloFont` (`displayXL`, `displayL`, `displayM`, `displayS`, `headline`, `body`, `callout`, `subhead`, `footnote`, `caption`, `captionUpper`, `numericHero`, `numericL`, `numericM`). Use text-style-relative fonts so Dynamic Type works. Add a `.captionUpper()` modifier (uppercase, tracking 1.2, semibold 11).
4. **Motion tokens:** create `Shared/Theme/HaloMotion.swift`:

| Token | Value | Use |
|---|---|---|
| `Motion.snappy` | `.spring(duration: 0.28, bounce: 0.15)` | Taps, toggles, chips, press states |
| `Motion.smooth` | `.spring(duration: 0.45, bounce: 0)` | Layout changes, card expand, tab content |
| `Motion.gentle` | `.spring(duration: 0.65, bounce: 0.05)` | Theme switches, large hero changes |
| `Motion.bouncy` | `.spring(duration: 0.5, bounce: 0.32)` | *Only* celebratory moments (ritual complete, purchase success) |
| `Motion.ring` | `.spring(duration: 0.9, bounce: 0)` | Progress rings sweep |
| `Motion.stagger(i)` | `smooth.delay(Double(i) * 0.04)`, capped at 8 items | List/section entrances |

   Plus a `@Environment(\.accessibilityReduceMotion)`-aware helper: `Motion.resolve(_ animation:, reduceMotion:)` returns `.easeInOut(duration: 0.2)` (opacity-only intent) when Reduce Motion is on. All views use these tokens. No ad-hoc `.easeInOut(duration: 0.3)` literals.
5. **Haptics:** replace the `model.haptic()` calls with SwiftUI's `.sensoryFeedback(_:trigger:)`: `.selection` for chips/segments/dial ticks, `.impact(weight: .light)` for primary buttons, `.success` for ritual complete / purchase / preset saved, `.warning` for destructive confirms. Respect the Settings haptics toggle through an environment flag.
6. **Shapes:** every rounded rectangle uses `style: .continuous`. Widgets use `ContainerRelativeShape`.

## 3. Component library rebuild (`Shared/Theme/Components/`)

Rebuild or create these, each with `#Preview` covering light, dark, a premium theme, and AX3 Dynamic Type:

| Component | Requirements |
|---|---|
| `ThemeBackground` | Bg + halo. On iOS 18 use a subtle **`MeshGradient`** (3×3, palette `bg`/`halo`/`accentSoft` at ≤ 25%) instead of the plain radial. **Static by default.** Only onboarding welcome and the paywall hero breathe (≤ 4% point drift over 8s, `TimelineView(.animation(minimumInterval: 1/30))`, paused when off-screen or Reduce Motion is on). Theme changes cross-fade the mesh colors with `Motion.gentle`. |
| `HaloCard` | Variants `.standard`, `.hero` (glass), `.inset`, `.plain` (no chrome, used for grouping). Shadows per SPEC §7.5 (two-layer soft shadow light, hairline border dark). On iOS 26 `.hero` uses `.glassEffect(.regular, in:)`. On iOS 18 it uses `.ultraThinMaterial` + `glassStroke` inner stroke. Reduce Transparency → solid. |
| `PressableStyle` (ButtonStyle) | Shared press feedback for any tappable card/row: scale 0.97, brightness −0.02, `Motion.snappy`. All tappable cards use this. Currently they use `.plain` with no feedback. |
| `HaloButton` | `.primary` (accent capsule, 56pt, inner top highlight 1pt white @ 20%, pressed glow), `.secondary`, `.glass`, `.text`. Supports `isLoading` (label cross-fades to a `ProgressView`, width stays fixed) and success state (label morphs to a checkmark with `.contentTransition(.symbolEffect(.replace))`, then back after 1.5s). |
| `HaloChip` + `ChipGroup` | Selection indicator is a **single capsule that slides** between chips via `matchedGeometryEffect` (namespace per group). Horizontal scroll with `.scrollTargetBehavior(.viewAligned)` and edge fade masks. |
| `HaloSegmented` | Custom segmented control with a sliding glass thumb (`matchedGeometryEffect`). Replaces `Picker(.segmented)` in Calendar (Day/Week/Month), Studio surface, and guide sheet. Keep it accessible: `accessibilityRepresentation { Picker(...) }`. |
| `ProgressRing` | Animatable via `Animatable` `progress`. Gradient stroke (`AngularGradient` accent → accent @ 70%), round caps, a **leading-end glow dot** at the tip, and optional segments (ritual ring) with 3° gaps. Sweeps with `Motion.ring` on appear and on change. Center label uses `.contentTransition(.numericText(value:))`. |
| `RollingNumber` | Text wrapper using `.contentTransition(.numericText(countsDown:))` + `.monospacedDigit()`. Use for all percentages, counts, streaks, durations, and prices. |
| `RitualCheck` | Circle → filled check: stroke trims around (0.25s), fill scales from center, the checkmark symbol draws in (`.symbolEffect(.bounce)`), 6 tiny accent particles burst once (`KeyframeAnimator`, ≤ 0.5s, Canvas-based, no per-particle views). Count rituals fill as a trimmed arc per step. `.sensoryFeedback(.success)` on completion. |
| `AgendaRow` / `TimelineView` | Vertical rail with calendar-colored dots. Past events dim to 60%. The **now indicator** is a glowing accent line + dot that moves smoothly with time (position recomputed once per minute, animated with `Motion.smooth`). |
| `PhoneFrame` + `LockScreenMock` | Real-looking device: continuous-radius bezel, Dynamic Island pill, wallpaper (theme-paired gradient/mesh), big clock in SF Pro Rounded-like system clock style, date line, inline + bottom-row widget slots rendered with the **real** `HaloWidgetContent` in vibrant simulation. Must render in `ImageRenderer` (no materials when `isExporting`). |
| `EmptyState` | Large SF Symbol with `.symbolEffect(.pulse)` once on appear (not looping), serif title, body, optional CTA. |
| `Toast` | Top-anchored glass capsule, slides + fades from the top with `Motion.snappy`, auto-dismiss 2.2s, single-instance queue. Used for "Preset saved", "Widgets refreshed", "Welcome to Premium". |
| `ShimmerPlaceholder` | Skeleton for any async content. Gradient sweep via `phaseAnimator`. Show only if data takes > 150ms. |

## 4. App-wide motion & navigation

- **Tab switches:** content cross-fades + 8pt rise (`Motion.smooth`). Tab icons use `.symbolEffect(.bounce, value: selection)` on select.
- **Zoom transitions (iOS 18):** use `matchedTransitionSource(id:in:)` + `.navigationTransition(.zoom(sourceID:in:))` for:
  - Today next-event card → Event detail
  - Theme card → Theme detail
  - Today "Your Halo" preview → Studio (switching tab is fine, but the preview card should scale into place)
  - Focus card → active Focus session (convert active session to a `fullScreenCover` per SPEC §6.7)
- **Sheets:** use `.presentationDetents`, `.presentationCornerRadius(32)`, `.presentationBackground(.thinMaterial)` (or palette bg under Reduce Transparency).
- **Scroll effects:** section headers and cards use `.scrollTransition(.interactive)`: opacity 0.6 → 1 and scale 0.96 → 1 at the top/bottom edges. Keep it subtle. The Today greeting collapses into the inline nav title with an opacity/blur cross-fade driven by `onScrollGeometryChange`.
- **Entrances:** on first appear per session, Today/Rituals/Studio sections stagger in (`Motion.stagger`, opacity + 12pt rise). Do **not** replay on every tab switch. Track with `@State hasAppeared`.
- **Theme switching** is a hero moment: the whole app re-tints with `Motion.gentle`. Colors interpolate. Do not rebuild the view tree. Do not change `id`s on theme change.

## 5. Screen-by-screen redesign

For each screen: keep features from SPEC §6, rebuild the layout and motion as below.

### Onboarding
- Six pages with a custom pager (not a stock page-dot `TabView` look): a custom capsule indicator that stretches between dots (`matchedGeometryEffect`), and a primary button pinned to the bottom that **persists across pages** and morphs its label (`.contentTransition(.interpolate)`).
- Page 1: the halo ring draws itself (trim 0→1, 1.2s), then the wordmark fades up letter-by-letter. Use a `TextRenderer` (iOS 18) for per-glyph opacity/offset, with a fallback to plain fade.
- Page 2: `LockScreenMock` rises in. Widgets drop into slots one by one with `Motion.bouncy` and a soft haptic each.
- Page 3: theme carousel with `.scrollTargetBehavior(.viewAligned)`, `.containerRelativeFrame`, and `.scrollTransition` (center card 1.0 scale, neighbours 0.88 + 0.6 opacity + slight 3D `rotation3DEffect` ≤ 8°). **The whole onboarding background re-tints live** to the centered theme.
- Pages 4–5: permission illustrations animate (agenda rows slide in, notification banners stack with spring). After the user grants permission, the CTA morphs to a checkmark before advancing.
- Page 6: three starter preset cards with a selection ring that slides. "Save my Halo" → success morph → onboarding dismisses with the Lock Screen mock zooming into the Today preview card (matched transition if feasible, otherwise a scale-fade).

### Today
- Header: date line (`captionUpper`) + greeting in `displayL` serif. The greeting collapses on scroll (Section 4).
- **Day progress hero**: a large `ProgressRing` (120pt) left, `RollingNumber` percent, "3 of 7 done" right. Ring sweeps on appear. Remove the redundant linear `ProgressView`.
- **Next event card** (glass hero): relative time "in 25 min" uses `Text(date, style: .relative)` and needs no per-second re-render. Calendar-color accent bar on the leading edge. "Count down" glass button. When an event becomes "NOW", the label cross-fades and the bar pulses once.
- **Timeline**: one card containing the rail-style `TimelineView` component (not one card per row), now-indicator, past events dimmed. All-day events as chips on top.
- **Rituals**: one horizontal row of ritual tiles (glyph in tinted circle + name + `RitualCheck`) inside a single plain group, with a "3 / 5" `RollingNumber`. Completing a ritual updates the day ring at the top *in the same animation transaction*.
- **Focus entry**: compact glass card with the last duration and a circular "play" button that zoom-transitions into the session.
- **Your Halo**: `PhoneFrame` mini preview (tilted 0°, soft float shadow) with "Edit" → Studio.
- Pull to refresh: custom indicator is fine, but the system one is acceptable. Content must not jump after refresh: use `.animation(Motion.smooth, value: events)` and stable `id`s.

### Calendar
- Custom `HaloSegmented` Day/Week/Month. Content between modes cross-fades + scales (0.98 → 1).
- **Day:** week scroller with a sliding selected-day capsule (`matchedGeometryEffect`). Horizontally paging hour grid (swipe between days with `.scrollTargetBehavior(.paging)`). Event blocks with calendar-color left bar + 10% fill, continuous radius 10. Now line glows. Auto-scroll to now − 1h with `scrollPosition`.
- **Week:** 7-column compact grid, paging by week.
- **Month:** grid with event dots. Selecting a day slides the selection circle (`matchedGeometryEffect`) and the agenda list below re-flows with `Motion.smooth`. Swiping between months is paged, and the month title rolls (`.contentTransition(.numericText)` for the year, push transition for the month name).
- Event detail sheet opens via zoom transition from its block/row.

### Widget Studio (signature screen, so spend the most effort here)
- Layout: the **phone preview is the hero**, taking the top ~55% and sticky. Controls live in a bottom **glass control tray** that scrolls under the preview. Replace every `Picker` and the `TextField(.roundedBorder)` with custom controls:
  - Surface: `HaloSegmented` (Lock Screen / Home Screen). Switching flips the preview with a cross-fade + subtle scale. The phone frame stays put; only the screen content changes.
  - Slots: tapping a slot in the preview selects it (dashed animated outline, `phaseAnimator` dash-phase marching, stops after 2 cycles). Controls edit the selected slot.
  - Size & Type: `ChipGroup`s with sliding selection. Changing type **morphs** the widget in the preview (`matchedGeometryEffect` on shared sub-elements like title/time, otherwise cross-fade + scale 0.96 → 1).
  - Theme: horizontal row of 8 swatch orbs (split bg/accent). Selection ring slides. Premium orbs show a tiny ✦. Changing theme re-tints the preview with `Motion.gentle`.
  - Preview state: wallpaper (Light / Dark / Photo) and data scenario (Live / Morning / Busy / Empty / Focus) as compact chips.
  - Preset name: inline editable title above the tray ("Ruby Agenda ✎"), not a bordered text field.
- Save: `HaloButton` with loading → success morph + toast "Preset saved". Saved presets appear in a horizontal carousel of mini phone thumbnails. A newly saved preset **flies** from the preview into the carousel (matched geometry or a scale/offset animation toward the carousel slot).
- Delete via context menu with a destructive confirm, not a raw trash button on every card.
- The "How to add" guide becomes a paged sheet with an **animated mini-illustration per step** (built in SwiftUI: a finger-press ripple on the lock screen mock, then the customize panel sliding up, and so on, looping with `phaseAnimator`), not a list of text cards.

### Themes
- 2-column gallery of tall cards. Each card shows a mini Home Screen medium widget over the paired wallpaper mesh. Cards respond to scroll with `.scrollTransition` (parallax: inner preview offsets ±12pt against the card).
- Theme detail via zoom transition: full-bleed preview carousel (Lock Screen, Home, Live Activity) with paging dots, palette strip whose swatches expand on tap to show token names, then the CTA. "Use theme" triggers the app-wide re-tint (Section 4) and a success haptic.

### Rituals
- Header: big segmented daily ring (one segment per ritual) with `RollingNumber` "3/5" and day streak "12 days ✦".
- Grouped list by time of day (Morning / Afternoon / Evening / Anytime) with serif group headers. Rows are **not** individual cards. Use one inset group per section with hairline separators (like Apple Reminders, but warmer).
- Swipe actions (complete / edit), and reordering with drag that has spring lift (scale 1.03 + shadow).
- Completing the last ritual of the day triggers a one-time "All done today" moment: the ring closes, a soft glow sweeps, the toast appears, plus `.sensoryFeedback(.success)`. Show it once per day.
- The add/edit sheet has a glyph grid with a sliding selection ring, a custom chip-based schedule picker, and a live preview of the ritual tile at the top that updates as you type.
- Ritual detail: 12-week grid that fills in with a diagonal stagger wave on appear (one `Canvas`, not 84 views animating independently).

### Focus
- **Setup:** replace the segmented picker + stepper with the **`FocusDial`** from SPEC §6.7: a 260pt circular dial, drag the knob around the ring (5–240 min, 5-min detents with `.selection` haptic per detent). The arc fills with an accent gradient and the center number rolls with `RollingNumber`. Quick chips 25 / 50 / 90 snap the dial with `Motion.smooth`. The label field is inline and borderless with suggestions as chips.
- **Active session:** `fullScreenCover`, reached via zoom transition. Dimmed theme background with a slow-breathing halo behind the ring (opacity 0.6 ↔ 0.9, 4s, paused under Reduce Motion). Timer text uses **`Text(timerInterval:countsDown:)`** and the ring uses `ProgressView(timerInterval:)` or an `Animatable` ring driven by a linear animation to the end date. **Delete the 1-second `TimelineView` that re-renders the whole screen.** For completion detection, use a single `Task.sleep(until:)` scheduled for `endDate`, cancelled on pause/end. Pause/Resume is a glass circle whose symbol morphs (`pause.fill` ↔ `play.fill`, `.contentTransition(.symbolEffect(.replace))`).
- **Completion:** the ring completes, a soft accent bloom, "50 minutes of focus. Beautiful." in serif, `.success` haptic.
- **Live Activity / Island preview:** a realistic mini Dynamic Island that **animates through compact → expanded → minimal** in a loop (`phaseAnimator`, 3 phases, ~2.5s each) above a Lock Screen banner mock. Free users see it under a frosted ✦ lock overlay with "Unlock Live Activities".
- History: a "This week" summary with `RollingNumber` total, and a compact 7-bar chart (Swift Charts, `BarMark`, rounded, accent) whose bars rise in on appear.

### Paywall
- Hero: three tilted phone frames (Ruby, Champagne, Midnight Gold) fanned out (no CoreMotion parallax). Animate them in once with a staggered fan-out and a slow breathing mesh behind.
- Feature list: rows stagger in, each with an accent ✦ that twinkles once (`symbolEffect(.bounce)`).
- Plan picker: custom cards with a sliding selection border (`matchedGeometryEffect`). The selected card lifts (scale 1.02 + shadow). Prices from `Product.displayPrice` with `RollingNumber`-style transition when switching plans. The CTA label morphs per plan (SPEC §14.3).
- Close button visible immediately. Purchase: loading state on the CTA → success morph → sheet dismisses → app-wide toast "Welcome to Halo Day Premium." + `.success` haptic. Premium chips across the app fade out.
- Keep every honesty rule from SPEC §6.8.

### Settings
- Keep a system `Form` (users expect it) but theme it: `scrollContentBackground(.hidden)` over `ThemeBackground`, row backgrounds `surface`, accent tint, SF Symbol icons in rounded tinted squares (like iOS Settings), and a Premium status hero row at the top with a subtle sheen (`phaseAnimator` gradient sweep, once on appear).

### Widgets & Live Activity (`HaloDayWidgets`, `WidgetContent.swift`)
- Refine typography and spacing per SPEC §10 ASCII layouts. Apply `WidgetStyle` per theme (numeral design, separators, now-marker), handle `.vibrant` / `.accented` / `.fullColor` per SPEC §9.2, and use `.widgetAccentable()` correctly.
- Add widget transition polish: `.contentTransition(.numericText())` on counts/percentages and `.transition(.push(from: .bottom))` on agenda rows so timeline reloads animate (WidgetKit animates these on iOS 17+). Use `.invalidatableContent()` on the interactive ritual buttons so taps show immediate feedback.
- Live Activity: match SPEC §11 layouts. Timer via `Text(timerInterval:)`, progress via `ProgressView(timerInterval:)`, symbol replace transitions on pause/resume, `keylineTint` = theme dark accent.

## 6. Performance rules (non-negotiable)

1. No `TimelineView(.periodic(by: 1))` or `Timer` driving UI anywhere a self-updating `Text(timerInterval:)`, `Text(date, style:)`, or `ProgressView(timerInterval:)` can do the job. Where a TimelineView is unavoidable, scope it to the **smallest possible subview**.
2. Animate only `opacity`, `scale`, `offset`, `rotation`, trims, and colors where possible. Avoid animating `frame` sizes of large containers, and never animate `blur` radius on big surfaces or more than one view at a time.
3. Particle/decoration effects use a single `Canvas` (or `drawingGroup()` on a small, isolated subtree), never dozens of views.
4. Stable identity: `ForEach` over `Identifiable` data with stable IDs. No `id: \.self` on structs that change, no `AnyView` in lists, and no conditional `if` that swaps whole view trees when a modifier would do (`.opacity`, `.disabled`).
5. Keep `body` cheap: no date formatting, sorting, filtering, or `Color(hex:)` inside `body`. Precompute in the model or in a `let` at the top of a small subview, and use cached `FormatStyle`s.
6. Lists with more than 20 items use `LazyVStack`/`List`. Calendar grids use `LazyVGrid`.
7. Materials/glass: max 2 stacked layers, never inside scrolling cells repeated many times. Rows inside a glass container are plain.
8. Verify with Instruments' **SwiftUI** template + **Animation Hitches** on a physical device or the oldest simulator available: zero hitches > 16ms in scroll of Today, Calendar Month, Studio, and during the theme switch. Report numbers in your summary.

## 7. Accessibility (must still pass)

- Reduce Motion: replace all springs/offsets/scales/3D with short opacity cross-fades. Stop all breathing/looping animations. Disable stagger and particles.
- Reduce Transparency: glass becomes solid `surface` + hairline.
- Dynamic Type up to AX3: layouts reflow (`ViewThatFits`, or switch HStack → VStack via `dynamicTypeSize.isAccessibilitySize`). The FocusDial keeps a usable size and exposes `accessibilityAdjustableAction` (± 5 min).
- Every custom control has correct accessibility traits, labels, values, and adjustable actions. Custom segmented/chips expose selection state.
- Contrast stays per SPEC (existing palette contrast tests must still pass).

## 8. Verification you must do

1. Build and run all tests: `xcodebuild -project HaloDay.xcodeproj -scheme HaloDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO test`. All green. Update UI tests whose selectors changed (keep accessibility identifiers stable where possible, or add them).
2. **Screenshot pass:** add `scripts/screenshots.sh` that boots the simulator, launches with a `-UITestScreenshotMode` launch argument (fixture data, fixed date 2026-10-05 10:05, onboarding skipped), and captures every main screen in **Pearl Halo light, Ruby Glass dark, Midnight Gold**, in both English and Vietnamese, into `docs/screenshots/`. Review them yourself for clipping, overflow, misalignment, and inconsistent spacing, and fix what you find.
3. Record 3 short screen recordings with `xcrun simctl io booted recordVideo` (onboarding, Studio theme/type switching, ritual complete → all done) into `docs/screenshots/` so motion can be reviewed.
4. `#Preview` for every new component and screen, covering light, dark, premium theme, AX3, Reduce Motion (via `.environment(\.accessibilityReduceMotion, true)` where applicable), and empty state.
5. Grep check: no `Color(hex:` outside the palette/resolver files, no `.easeInOut(duration:` literals outside `HaloMotion.swift`, and no `TimelineView(.periodic(from:` in Focus.

## 9. Phases and commits

1. `chore: snapshot before UI rebuild` (existing changes) → branch `ui/v1-polish`
2. `feat(design): resolved palette, typography, motion, haptics tokens` + tint bug fix
3. `feat(design): component library` (Section 3) + previews
4. `feat(ui): navigation, zoom transitions, scroll effects`
5. `feat(ui): Today` → `Calendar` → `Studio` → `Themes` → `Rituals` → `Focus` → `Paywall` → `Onboarding` → `Settings` (one commit each)
6. `feat(widgets): widget and Live Activity polish`
7. `perf: hitch pass` + `test: screenshots and UI test updates`

Build and run the tests at the end of each phase. Do not move on with a red build.

## 10. Final deliverable

When done, reply with:
- A summary per phase of what changed and why.
- A list of any non-UI changes (with justification).
- Instruments hitch results for the four scenarios in Section 6, rule 8.
- Paths to the screenshot set and recordings.
- Anything you could not achieve on iOS 18 (and the iOS 26-only enhancements you gated behind `#available`).
- Known gaps or follow-ups, stated honestly. Do not claim something is polished if you have not looked at its screenshot.
