# Halo Day Product & Design Spec

> **Your day, beautifully on display.**
>
> Version 1.0 · 2026-10-05 · Status: Ready for MVP implementation
> Audience: implementation agent (Codex) + product/design owner

---

## 0. How to Use This Document

This spec describes the product, UX, and visual system for **Halo Day**, a native iOS app built in **SwiftUI** with **WidgetKit**, **ActivityKit**, **EventKit**, **UserNotifications**, and **StoreKit 2**.

- Sections 1–4: what we are building and why.
- Sections 5–8: screens, flows, and the visual/theme system.
- Sections 9–11: widgets, Lock Screen, Live Activities.
- Sections 12–14: monetization, App Store, copy.
- Sections 15–17: MVP scope, technical architecture, build order, acceptance criteria.

**Rules for the implementer**

1. When this spec conflicts with an Apple platform constraint, the platform wins. Section 1.4 lists the constraints. Note the conflict in a code comment.
2. All colors, fonts, spacing, and radii come from the token system in Section 7. Do not hard-code hex values in views.
3. Every user-facing string lives in `Localizable.xcstrings`. Use the copy in Section 14 verbatim for English.
4. MVP scope is defined in Section 15. Anything marked **Future** must not be built in v1. Leave a clean seam for it where noted.

---

## 1. Product Positioning

### 1.1 One-liner

Halo Day is a premium Lock Screen planner. It turns your calendar, rituals, and focus time into calm, beautiful widgets you see every time you pick up your iPhone.

### 1.2 Positioning statement

For people who care how their phone looks *and* want to stay on top of their day, Halo Day shows today's schedule, progress, and rituals on the Lock Screen in an editorial, luxury style. Generic calendar widgets are utilitarian and widget-theming apps are only decoration. Halo Day is both useful and beautiful, and it is honest about what iOS allows.

### 1.3 Pillars

| Pillar | Meaning | Design consequence |
|---|---|---|
| **Glanceable** | The day is readable in under 2 seconds | Strict information hierarchy. Max 3 agenda rows per widget. Large time numerals. |
| **Beautiful** | Worth a screenshot | Editorial serif display type, restrained palettes, frosted glass, generous whitespace |
| **Personal** | Feels like *my* day | Rituals, greeting, presets, theme choice |
| **Honest** | No fake promises | Clear explanation of iOS limits. Real trial terms. No dark patterns. |
| **Private** | Calendar data stays on device | No account, no server, no third-party analytics in MVP |

### 1.4 iOS platform constraints (read before building)

These limits shape the whole product. Explain them to users in plain language (see Section 14.6).

| Constraint | Reality | How Halo Day handles it |
|---|---|---|
| **Lock Screen redesign** | Apps cannot draw on or redesign the Lock Screen. Only the user can edit it, using system widgets, wallpaper, and the clock style. | We supply **widgets** (WidgetKit) and **wallpapers** (saved to Photos). We guide the user through adding them. |
| **Adding widgets** | Apps cannot add widgets programmatically. | Widget Studio shows an illustrated step-by-step guide plus a "Copy setup steps" option. |
| **Lock Screen widget color** | Lock Screen accessory widgets (`accessoryInline/Circular/Rectangular`) render in **vibrant mode**. The system desaturates content and tints it to match the wallpaper and clock. Custom colors do **not** show. | On the Lock Screen, themes are expressed through **typography, layout, glyph style, density, and background on/off**, not color. Full theme color appears in Home Screen widgets, StandBy, the in-app UI, and Live Activities. Widget Studio previews must simulate vibrant rendering honestly. |
| **Lock Screen widget slots** | Max 4 circular (or 2 rectangular, or a mix filling the row) below the clock, plus 1 inline above the clock. | Presets are designed around these slot combinations (Section 10). |
| **Widget refresh** | Widgets are not live views. They render from a **timeline** and have a daily reload budget (roughly 40–70 reloads per day, system-managed). | Precompute timeline entries at event boundaries. Use `Text(date, style: .timer/.relative)` and `ProgressView(timerInterval:)` for self-updating countdowns. Call `WidgetCenter.reloadTimelines` only on real data changes. |
| **Widget interactivity** | Since iOS 17, widgets support `Button`/`Toggle` backed by `AppIntent`. No scrolling, text input, or arbitrary gestures. | Ritual check-off and "Start focus" are interactive buttons. Everything else deep-links into the app. |
| **Live Activities** | Max ~8 hours active. The system may keep it on the Lock Screen for up to 4 more hours after it ends. Payload must stay under 4 KB. Dynamic Island exists only on iPhone 14 Pro and later; other devices show Lock Screen and banner only. | Focus sessions max out at 4 hours. Event countdowns start ≤ 60 min before an event. Every layout degrades gracefully without the Island. |
| **Live Activity color** | Live Activities **do** support full color on the Lock Screen. | This is where Ruby/Champagne/Gold accents can appear on the Lock Screen. It's a key premium showcase. |
| **Calendar** | EventKit requires the user's permission. iOS 17+ uses `requestFullAccessToEvents()`. Read-only use still needs full access to list events. | Ask in context during onboarding, explain the value first, and offer a full fallback experience without calendar access. |
| **Wallpaper** | Apps cannot set the wallpaper. | Premium wallpaper packs are saved to Photos with add-only permission (`NSPhotoLibraryAddUsageDescription`). The user sets the wallpaper themselves. We show instructions. |
| **Notifications** | Local notifications only (no server). Max 64 pending local notifications per app. | Reminders scheduler keeps a rolling window of the next 64 triggers, re-planned on app launch and on background refresh. |

---

## 2. Target Users

### 2.1 Primary personas

| Persona | Who | Job to be done | What wins them |
|---|---|---|---|
| **The Aesthetic Planner** (core) | 18–34, mostly women, active on TikTok/Pinterest/Instagram. Customizes the Lock Screen every season. Uses digital planners. | "I want my phone to look beautiful *and* help me keep my day together." | Themes, wallpaper pairings, shareable setups |
| **The Busy Professional** | 25–45. Calendar-heavy (work + personal). Checks the phone 100+ times a day. | "Show me what's next without unlocking or opening Calendar." | Next-event widget, agenda reliability, Live Activity countdowns |
| **The Ritual Builder** | 20–40. Building habits (water, journaling, gym, skincare, reading). | "Keep my routines in front of me, gently." | Ritual widgets, streaks, interactive check-off |
| **The Focus Seeker** | Students and creatives doing deep work. | "Help me protect focus blocks and see the time I have left." | Focus Live Activity, Dynamic Island timer |

### 2.2 Non-goals (who we are not for in v1)

- Teams and shared calendars management (we read shared calendars but don't manage sharing).
- Full calendar editing power users (we create simple events only, and only in a **Future** version).
- Android, iPad-first, Mac (iPad runs the iPhone layout; no iPad-specific UI in MVP).

---

## 3. Core Use Cases

| # | Use case | Trigger | Outcome | MVP |
|---|---|---|---|---|
| U1 | See next event without unlocking | Raise phone | Rectangular widget shows next event, time, and countdown | ✅ |
| U2 | See whole day at a glance | Morning, open app | Today screen with greeting, progress, and timeline | ✅ |
| U3 | Make Lock Screen beautiful | First week | Choose a theme, preview widgets, save a preset, follow the add-widget guide, save a matching wallpaper | ✅ |
| U4 | Track daily rituals | Throughout day | Tick a ritual from the app or the Home Screen widget. Streak updates. | ✅ |
| U5 | Run a focus session | Deep-work block | Live Activity with timer on the Lock Screen and Dynamic Island | ✅ (Premium) |
| U6 | Countdown to an upcoming event | Event within 60 min | Optional Live Activity counting down | ✅ (Premium) |
| U7 | Month awareness | Glance | Month progress widget ("Oct · 16% · 26 days left") | ✅ |
| U8 | Countdown to a date | Birthday, trip, launch | Countdown widget "12 days · Lisbon" | ✅ |
| U9 | Switch looks quickly | Mood or season change | Swap presets. Widgets configured with "Active preset" update automatically. | ✅ (Premium presets >1) |
| U10 | Share setup | After customizing | Export a "Halo card" image of the setup | **Future** |

---

## 4. Information Architecture

### 4.1 Navigation model

A `TabView` with **5 tabs**. Use the system tab bar so it adopts Liquid Glass on iOS 26 automatically. Do not build a custom tab bar.

```
Halo Day
├── Today            (tab 1, default)
│   ├── Next event card → Event detail (sheet)
│   ├── Timeline → Event detail (sheet)
│   ├── Rituals checklist → Rituals tab
│   ├── Focus entry → Focus setup (sheet)
│   └── Lock Screen preview card → Widget Studio
├── Calendar         (tab 2)
│   ├── Segmented: Day | Week | Month
│   ├── Event detail (sheet)
│   └── Calendar sources (sheet)
├── Studio           (tab 3, center, signature)
│   ├── Lock Screen mock + controls
│   ├── Theme picker (inline) → Themes gallery (push)
│   ├── Presets list (sheet)
│   └── How to add widgets (sheet)
├── Rituals          (tab 4)
│   ├── Ritual list + daily ring
│   ├── Ritual detail (push) → edit
│   └── Add ritual (sheet)
└── Focus            (tab 5)
    ├── Setup (duration, label, linked ritual)
    ├── Active session (full screen cover)
    └── Live Activity / Island preview

Global
├── Settings (gear in Today nav bar, sheet)
├── Paywall (sheet, from any premium gate)
└── Onboarding (fullScreenCover on first launch)
```

Tab icons (SF Symbols): `sun.horizon`, `calendar`, `square.on.square.dashed` (Studio), `circle.dashed.inset.filled` (Rituals), `timer`.

Themes is **not** its own tab. It lives in Studio ("Themes" button → gallery) and in Settings → Appearance. This keeps the tab bar to 5 and makes Studio the hub for looks.

### 4.2 Deep links (URL scheme `haloday://`)

| URL | Destination |
|---|---|
| `haloday://today` | Today tab |
| `haloday://event/{eventIdentifier}` | Today + event detail sheet |
| `haloday://calendar?date=2026-10-05` | Calendar day view |
| `haloday://studio?preset={id}` | Studio with preset loaded |
| `haloday://rituals` | Rituals tab |
| `haloday://focus` | Focus tab (or active session if running) |
| `haloday://paywall?source={source}` | Paywall sheet |

Every widget sets `.widgetURL` or `Link` to one of these.

---

## 5. Main User Flows

### 5.1 First launch → first preset (activation flow)

```
Launch
 └─ Onboarding 1 Welcome ─▶ 2 Lock Screen story ─▶ 3 Choose style
     └─ 4 Connect Calendar ──[Allow]──▶ EventKit full access
     │                     └─[Not now]─▶ skip (sample data in previews)
     └─ 5 Notifications ──[Allow]──▶ UNUserNotificationCenter auth
     │                  └─[Not now]─▶ skip
     └─ 6 First preset (pick a starter layout) ─▶ save preset
         └─ "How to add to Lock Screen" sheet (4 steps)
             └─ Today tab (preview card shows the saved preset)
```

**Activation metric:** user saves a preset **and** a Halo Day widget is installed within 24h. Detect installed widgets with `WidgetCenter.shared.getCurrentConfigurations`.

The paywall is **not** shown during onboarding. A premium theme picked in step 3 is applied as a **preview** with a small "Premium preview" chip. When the user taps Save in step 6, a soft paywall appears: "Keep Ruby Glass?" with a "Continue with Pearl Halo" alternative. The user always has a free path.

### 5.2 Add widget to Lock Screen (guided)

1. Studio → "Add to Lock Screen" button.
2. Sheet shows 4 illustrated steps (Section 14.6). Each step has a looping mini-animation built in SwiftUI (no video).
3. "I've added it" button → app checks `getCurrentConfigurations`. If found: success toast "Your Halo is live." If not: "We can't see it yet. Widgets sometimes take a moment. Try again." plus a secondary "Show steps again" button.

### 5.3 Ritual check-off

- **In app:** tap the circle → haptic `.success` → ring animates → streak recalculates → `WidgetCenter.reloadTimelines(ofKind: "RitualWidget")`.
- **From Home Screen widget:** `Button(intent: ToggleRitualIntent(ritualID:))` writes to the shared store and reloads timelines.
- **Lock Screen circular widget:** shows today's ritual ring. Tapping opens the app on Rituals. Lock Screen interactive buttons are possible but easy to trigger by accident, so we deep-link instead.

### 5.4 Focus session

```
Focus tab → choose duration (25 / 50 / 90 / custom) → optional label/ritual
 → Start
   ├─ Premium & Live Activities enabled → Activity.request(...)  → Active screen
   └─ Free → in-app timer + local notification at end → Active screen
        (Live Activity preview shown with lock + "Unlock Live Activities")
 Active: Pause / Resume / End early
 End → completion sheet ("50 minutes of focus. Beautiful.") → log session → optional ritual check
```

### 5.5 Event countdown Live Activity (Premium)

- Setting: "Countdown before events" (Off / 15 / 30 / 60 min). Default Off.
- An app process must be alive to start a Live Activity locally. MVP approach: when the app is foregrounded or `BGAppRefreshTask` runs, and an event starts within the chosen window, start the activity. Mark this **best-effort** in the UI ("Starts when Halo Day refreshes. Usually on time, sometimes a little late."). Push-to-start is **Future** (needs a server).
- Also add a manual "Count down to this" button in event detail. This always works.

### 5.6 Upgrade

Any premium gate → `PaywallView(source:)` sheet → purchase via StoreKit 2 → on success: dismiss, unlock immediately, show confetti-free elegant toast "Welcome to Halo Day Premium."

---

## 6. Screen-by-Screen UX Specification

Conventions:
- **Layout:** 16pt horizontal screen margins (`space.4`). Content max width 600pt, centered on iPad.
- **Backgrounds:** every screen uses `ThemeBackground` (theme `bg` plus a subtle halo gradient; Section 7.7).
- **Navigation titles:** large titles use display serif (Section 7.2) via a custom `.haloLargeTitle()` modifier. Inline titles use SF Pro semibold.
- All tap targets ≥ 44×44pt.

### 6.1 Onboarding (6 screens)

Container: `TabView` with `.page` style, custom dot indicator (Section 7.9). There is no Skip button on screens 1–2. Screens 4–5 have "Not now". There is a back chevron top-left from screen 2 onward.

Visual base: full-bleed `ThemeBackground` using **Pearl Halo**. On screen 3 and later, the background switches live to the selected theme.

| # | Screen | Layout | Copy | Primary CTA | Secondary |
|---|---|---|---|---|---|
| 1 | **Welcome** | Centered halo mark (animated ring that draws in over 1.2s), app name in display serif 44pt, tagline below | See 14.1 | "Begin" | — |
| 2 | **See your day on the Lock Screen** | iPhone Lock Screen mock (component `LockScreenMock`), centered at 70% height, with agenda and month widgets fading in one by one | See 14.1 | "Continue" | — |
| 3 | **Choose your visual style** | Horizontal carousel of 8 theme cards (160×240), snap paging. Selected card scales to 1.0, others 0.92. Premium cards show a small "✦ Premium" chip. | See 14.1 | "Continue with {Theme}" | — |
| 4 | **Connect Calendar** | Mini agenda illustration using sample events. Privacy line with `lock.fill` glyph. | See 14.1 | "Connect Calendar" → system prompt | "Not now" |
| 5 | **Enable Notifications** | Stacked notification mock (2 banners in theme style) | See 14.1 | "Allow reminders" → system prompt | "Not now" |
| 6 | **Create your first preset** | 3 starter layout cards (Section 10.2): *Agenda*, *Ritual*, *Minimal*. Each shows a Lock Screen mock thumbnail. | See 14.1 | "Save my Halo" | — |

After screen 6: present the "How to add" sheet (5.2), then land on Today. Persist `hasCompletedOnboarding = true` only after screen 6 Save.

Motion: page transitions use the system page style. Elements on each page stagger in (opacity 0→1, y +12→0, 0.45s, `.smooth`, 60ms stagger). Respect Reduce Motion: no stagger or offset, opacity only.

### 6.2 Today

Purpose: the daily dashboard. It is calm, not crowded. Scrolls vertically.

```
┌──────────────────────────────────┐
│ MONDAY, 5 OCTOBER          ⚙︎    │  ← caption, ink2, tracking +1.2
│ Good morning, Tony.              │  ← display serif 34
│                                  │
│ ┌──────────────────────────────┐ │
│ │ ◯ 42%  Day progress           │ │  ← Progress card
│ │ ▓▓▓▓▓▓▓▓░░░░░░░  3 of 7 done  │ │
│ └──────────────────────────────┘ │
│ ┌──────────────────────────────┐ │
│ │ NEXT · in 25 min              │ │  ← Next event hero card (glass)
│ │ Design review                 │ │
│ │ 10:30 – 11:15 · Studio B  ● Work│
│ │ [Count down]                  │ │
│ └──────────────────────────────┘ │
│ Today                    See all │
│  09:00 ● Standup          ✓ past │  ← Timeline (vertical line + dots)
│  10:30 ● Design review   ← now   │
│  13:00 ● Lunch with Mai          │
│  ...                             │
│ Rituals                   3 / 5  │
│  ◉ Water   ◉ Journal  ◯ Read ... │  ← horizontal ritual chips
│ ┌──────────────────────────────┐ │
│ │ Focus  ▷ Start 50 min         │ │  ← Focus entry card
│ └──────────────────────────────┘ │
│ ┌──────────────────────────────┐ │
│ │ [Lock Screen mini preview]    │ │  ← Preview card → Studio
│ │ Your Halo · Ruby Agenda  Edit │ │
│ └──────────────────────────────┘ │
└──────────────────────────────────┘
```

**Components and behavior**

| Element | Spec |
|---|---|
| Date line | `caption.upper` style. Format: `EEEE, d MMMM`, uppercase, localized. |
| Greeting | Display serif `title1`. Text by time of day: 05–11 "Good morning", 12–17 "Good afternoon", 18–22 "Good evening", 23–04 "Still up". Appends `, {firstName}.` if a name is set in Settings. Otherwise ends with ".". |
| Day progress | "Day progress" = weighted blend: 50% elapsed share of the user's **day window** (default 07:00–22:00, editable in Settings) + 50% completed rituals share. If there are no rituals, use 100% time. Ring (`ProgressRing`, 44pt) + label + linear bar + "{n} of {m} done" where n/m = past events + completed rituals out of total. |
| Next event card | Glass card (`GlassCard.hero`). Shows the next non-all-day event that has not ended. If one is ongoing: label "NOW · ends in 18 min". Fields: title (headline serif 22), time range, location (1 line, truncated), calendar color dot + calendar name. Button "Count down" (Premium gate → Live Activity). Tap card → event detail. |
| Timeline | Today's timed events, all-day events pinned on top as chips. Past events at 45% opacity with strikethrough-free styling (just dimmed). A "now" indicator is a 2pt accent line with a 6pt dot, positioned between rows by time. Shows max 6 rows, then "See all" → Calendar day view. |
| Rituals row | Horizontal scroll of `RitualChip` (glyph + name + check state). Tap toggles. Long-press → ritual detail. Header shows "{done} / {total}". |
| Focus entry | Card with last-used duration. "Start {n} min" starts immediately with last settings. Tap elsewhere → Focus tab. |
| Lock Screen preview | `LockScreenMock` at 0.55 scale, rendering the **active preset**. Footer: "Your Halo · {preset name}" + "Edit" → Studio. |

**States**

- *Loading:* skeleton shimmer on cards for ≤ 300ms. EventKit is local, so it is usually instant.
- *No calendar access:* the Next card becomes the "Connect Calendar" card (copy 14.5). The timeline is hidden.
- *No events today:* Next card shows the empty state (14.5). Timeline is hidden.
- *All events done:* Next card: "That's a wrap for today." + tomorrow's first event preview.
- *Pull to refresh:* re-fetch EventKit and reload widget timelines.

### 6.3 Widget Studio (signature screen)

Purpose: design what goes on the Lock Screen and Home Screen, preview it honestly, save it as a preset, and learn to install it.

```
┌──────────────────────────────────┐
│ Studio                 Presets ▾ │
│ ┌──────────────────────────────┐ │
│ │      [wallpaper sample]       │ │
│ │   Mon 5 Oct  · ☀︎ ...inline   │ │  ← LockScreenMock (≈ 62% screen h)
│ │          10:24               │ │
│ │  [ rect widget ][ rect widget]│ │
│ └──────────────────────────────┘ │
│  ○ Light wall ○ Dark wall ○ Photo│  ← Preview state (wallpaper)
│  ○ Morning  ○ Busy  ○ Empty      │  ← Preview state (data scenario)
│ ───────────────────────────────── │
│ SURFACE   [Lock Screen | Home]    │
│ SIZE      [Inline][Circle][Rect]  │  ← or [S][M][L] for Home
│ TYPE      Agenda · Month · Week…  │  ← horizontal chips, 8 types
│ THEME     ● ● ● ● ● ● ● ●  Themes›│
│ DATA      Calendars: All (3)   ›  │
│ ───────────────────────────────── │
│ [ Save preset ]  [ Add to Lock Screen ] │
└──────────────────────────────────┘
```

**Controls**

| Control | Values | Notes |
|---|---|---|
| **Surface** | Lock Screen / Home Screen | Switches the mock between Lock Screen and Home Screen grid |
| **Slot editor** (Lock Screen) | Inline slot + bottom row (Rect+Rect, Rect+Circle+Circle, 4×Circle) | Tap a slot in the mock to select it (selected slot gets a 1.5pt dashed accent outline). Controls below edit the selected slot. |
| **Size** | Lock: Inline / Circular / Rectangular. Home: Small / Medium / Large | Disabled options are hidden, not greyed, when a type doesn't support a size (matrix in 9.3) |
| **Type** | Today Agenda, Month Progress, Week Strip, Mini Calendar, Habit Streak, Focus Session, Countdown, Daily Ritual | Chip row. Premium types show ✦. |
| **Theme** | 8 swatches + "Themes ›" link | Swatch = 28pt circle split diagonally between `bg` and `accent`. Selected swatch has a 2pt ring. |
| **Data source** | Agenda: calendars multi-select + "Include all-day". Ritual: which ritual(s). Countdown: date + title. Focus: none. Month/Week/Mini: first weekday. | Push to a `Form`. |
| **Preview state: wallpaper** | Light wallpaper / Dark wallpaper / My photo (PhotosPicker, local only, not saved unless user chooses) | Lock Screen preview applies the **vibrant simulation** (9.2) |
| **Preview state: data** | Live / Morning / Busy day / Empty day / Focus running | "Live" uses real data. Others use fixtures (Section 16.6). |
| **Save preset** | Name field (default "{Theme} {Type}") | Free tier: 1 preset (overwrites). Premium: unlimited. Saving a 2nd preset on free shows the paywall (source `preset_limit`). |
| **Add to Lock Screen** | Opens the How-to sheet (5.2) | Home Screen surface shows "Add to Home Screen" with its own steps |

**Honesty banner** (shown once per install, dismissible, Lock Screen surface only):
> "On the Lock Screen, iOS tints widgets to match your wallpaper. Your theme shapes the type and layout there. Full color shows on the Home Screen, in StandBy, and in Live Activities."

**Presets sheet:** list of saved presets (thumbnail, name, date). Swipe to delete, tap to load, star to set as **Active preset**. The Active preset drives any widget configured with "Active preset" (default).

### 6.4 Themes gallery

Pushed from Studio and Settings. 2-column grid of `ThemeCard` (aspect 3:4). Each card shows a mini Home Screen medium widget in that theme over its paired wallpaper, plus theme name (serif 17) and mood line (caption).

Tap → **Theme detail**: large preview carousel (Lock Screen mock, Home medium, Live Activity), palette strip (5 swatches with token names), "Pairs with" wallpaper thumbnails, and CTA:
- Free theme: "Use {Theme}".
- Premium, not subscribed: "Preview" (applies for the session with a chip) + "Unlock with Premium".
- Premium, subscribed: "Use {Theme}" + "Save wallpaper".

Full theme definitions: Section 8.

### 6.5 Calendar

Segmented control at the top: **Day | Week | Month** (`Picker(.segmented)`). Persist the last selection.

**Day view**
- Horizontal date scroller (7 visible days, centered on the selected day, swipe to change weeks). The selected day is shown as a filled accent capsule with `accentOn` text.
- An all-day lane at the top shows chips.
- Hour grid from 00:00 to 24:00, auto-scrolled to now − 1h. Hour rows are 56pt tall. Event blocks are positioned by time with a 3pt left bar in the calendar color and a surface fill at 8% calendar color. Overlapping events split the width into columns.
- The now line is shown on today only.

**Week view**
- 7 columns (respect `Calendar.current.firstWeekday` or the Settings override), compact blocks, horizontal paging by week.
- Tap a block → event detail. Tap a header day → Day view.

**Month overview**
- Grid of days. Each day cell shows the date numeral (SF Pro Rounded 15) and up to 3 dots (calendar colors), or "+n".
- Today: accent ring. Selected: filled accent.
- Below the grid: the agenda list for the selected day.
- Top: month progress line "October · 16% complete" (Month Progress component).

**Event detail (sheet, medium/large detents)**
- Title (serif 24), date and time, location (tap → Apple Maps), calendar source (color dot + calendar name + account, e.g. "Work · iCloud"), notes (max 6 lines, expandable), URL.
- Actions: "Count down" (Premium), "Open in Calendar" (`calshow:` URL with the event's start date as seconds since 2001-01-01), "Add reminder" (local notification at −10/−30/−60 min).
- MVP is **read-only**. No editing. This avoids write-permission complexity.

**Calendar sources indicator**
- Toolbar button `line.3.horizontal.decrease.circle` → sheet listing `EKSource` groups with their calendars. Each calendar has a toggle and its color. Toggled-off calendars are excluded app-wide and from widgets (unless a widget overrides its data source).
- A subtle header chip in all Calendar views: "3 calendars" → opens the same sheet.

**Empty / denied states**
- *No access:* full-screen empty state with "Connect Calendar" CTA (14.5). If status is `.denied`, the CTA opens `UIApplication.openSettingsURLString`.
- *No events on the selected day:* inline empty text "Nothing scheduled. A rare, open day."

### 6.6 Rituals

**List screen**

```
Rituals                              +
┌───────────────────────────────────┐
│   ◯◯◯ Daily ring  3/5             │  ← ring segmented per ritual
│   Tuesday streak: 12 days ✦       │
└───────────────────────────────────┘
Morning
  ◉ Water 8 glasses     🔥 12   ✓
  ◯ Journal             🔥 4
Anytime
  ◯ Read 20 pages       🔥 0
Evening
  ◯ Skincare            🔥 31
┌───────────────────────────────────┐
│ Lock Screen preview: [circle][rect]│ ← RitualWidget preview → Studio
└───────────────────────────────────┘
```

- Rituals are grouped by **time of day**: Morning / Afternoon / Evening / Anytime.
- Row: glyph (SF Symbol in a 32pt tinted circle), name, optional target ("8 glasses"), streak count with a small flame-free glyph (use `sparkle`, not fire; it fits the brand better), and a check circle on the right.
- **Counted rituals** (e.g. water 8×): tap increments, long-press decrements. The check circle fills progressively.
- **Daily ring:** one segment per ritual. Completed segments are accent, the rest are hairline.
- **Overall streak:** consecutive days where ≥ 80% of scheduled rituals were completed. Label: "Day streak".
- **Per-ritual streak:** consecutive *scheduled* days completed. Days the ritual isn't scheduled don't break the streak.

**Add / edit ritual (sheet)**
- Name (required, ≤ 24 chars)
- Glyph picker: a curated grid of 40 SF Symbols (e.g. `drop`, `book`, `figure.walk`, `moon.stars`, `leaf`, `cup.and.saucer`, `pencil.line`, `sparkles`, `heart`, `dumbbell`, `bed.double`, `sun.max`, `face.smiling`, `pills`, `bag`, `music.note`, `camera`, `paintbrush`, `brain.head.profile`, `wind`)
- Type: Check once / Count (target 2–20)
- Schedule: Every day / Weekdays / Custom days
- Time of day: Morning / Afternoon / Evening / Anytime
- Reminder: Off / time picker (local notification, repeating per schedule)
- Free tier: up to **3 rituals**. Adding a 4th shows the paywall (source `ritual_limit`).

**Ritual detail:** a 12-week contribution-style grid (squares, accent intensity by completion), current and best streak, completion rate (30d), and Edit/Delete.

### 6.7 Focus

**Setup**
- Large circular dial (`FocusDial`, 260pt). Drag around the ring to set 5–240 min in 5-min steps, with a haptic `.selection` per step.
- Quick chips: 25 · 50 · 90 · Custom.
- Label field (optional): "What are you focusing on?" with suggestions from today's event titles and ritual names.
- Toggle: "Show on Lock Screen & Dynamic Island" (Premium; locked with ✦ on free).
- CTA: "Begin focus".

**Active session (fullScreenCover)**
- Theme background darkens (Graphite overlay 60%), or `bg` stays in dark themes.
- Big countdown `Text(timerInterval:)` in SF Pro Rounded, ultralight, 76pt, monospaced digits.
- Progress ring around the time (accent stroke 4pt, track hairline).
- Label in serif 20 under the time.
- Controls: Pause/Resume (circle 64pt glass), End (text button, confirm dialog "End focus early?").
- Idle timer disabled while active (`UIApplication.shared.isIdleTimerDisabled = true`).
- On completion: soft haptic, local notification (if the app is backgrounded), completion sheet.

**Live Activity / Dynamic Island preview**
- Below the setup dial (free and premium): a "Preview" section with a segmented toggle *Lock Screen | Island*, rendering the actual Live Activity views at mock scale inside a phone-frame component. Free users see it with a ✦ lock overlay and "Unlock Live Activities".

**Session log:** stored, shown as "This week: 4h 20m focused" in Focus setup header. (Charts are **Future**.)

### 6.8 Paywall

Presented as a sheet (`.large` detent, no drag-dismiss interception; the close X is always visible top-right after 0s, with no delayed close button).

```
┌──────────────────────────────────┐
│                               ✕  │
│   [Hero: 3 phones fan, Lock      │
│    Screens in Ruby, Champagne,   │
│    Midnight Gold]                │
│                                  │
│   Make every glance beautiful.   │  ← serif 32
│   All themes, advanced widgets,  │
│   and Live Activities. Your day, │
│   at its most beautiful.         │
│                                  │
│   ✦ All 8 luxury themes          │
│   ✦ Advanced widgets & presets   │
│   ...                            │
│                                  │
│  ┌ Yearly  $24.99/yr  ($2.08/mo) ┐ BEST VALUE
│  │ 7-day free trial              │
│  └───────────────────────────────┘
│  ┌ Monthly  $3.99/mo             ┐
│  ┌ Lifetime $49.99 once          ┐
│                                  │
│  [ Start 7-day free trial ]      │
│  Then $24.99/year. Cancel anytime│
│  in Settings.                    │
│  Restore · Terms · Privacy       │
└──────────────────────────────────┘
```

Rules (honest paywall):
- Plan cards always show the **full billed price** in the largest price text. The per-month equivalent is secondary.
- Trial terms appear directly under the CTA, not hidden.
- CTA text changes by plan: Yearly "Start 7-day free trial", Monthly "Subscribe for $3.99/month", Lifetime "Buy once for $49.99".
- Use `Product.displayPrice` for localized prices. Never hard-code them.
- Trial eligibility: check `product.subscription?.isEligibleForIntroOffer`. If not eligible, hide the trial copy.
- Show the paywall at most once per session automatically (onboarding soft gate only). All other presentations are user-initiated by tapping a locked feature.
- Free features stay free forever. No downgrading of existing free functionality.

Copy: Section 14.3.

### 6.9 Settings (sheet from Today ⚙︎)

`Form` with grouped sections:

1. **Premium:** status row ("Halo Day Premium · Renews 5 Oct 2027" or "Upgrade to Premium ›"), Restore Purchases, Manage Subscription (`.manageSubscriptionsSheet`).
2. **Profile:** First name (for greeting).
3. **Appearance:** App theme (→ Themes), Appearance (System/Light/Dark, for themes that support both), App icon (Future), Haptics toggle.
4. **Day:** Day starts at (default 07:00), Day ends at (default 22:00), First day of week (System/Mon/Sun).
5. **Calendars:** Access status, Calendars shown (→ sources sheet), Include all-day events.
6. **Notifications:** Access status, Event reminders (Off/5/10/15/30 min), Morning brief (Off/time; "Your day: 4 events, first at 9:00"), Ritual reminders master toggle.
7. **Live Activities:** Focus sessions on Lock Screen (toggle), Countdown before events (Off/15/30/60), with a note about best-effort timing. Shows system status from `ActivityAuthorizationInfo().areActivitiesEnabled`.
8. **Widgets:** "How to add widgets", "Refresh widgets now".
9. **Wallpapers:** Saved packs (Premium), "How to set a wallpaper".
10. **About:** Privacy ("Your calendar never leaves your iPhone."), Terms, Rate Halo Day, Contact (mailto), Version.

---

## 7. Visual Design System

### 7.1 Principles

1. **Restraint.** Use one accent per screen region. Accent is for *meaning* (now, next, done, primary action), never decoration.
2. **Editorial hierarchy.** Serif for moments (dates, greetings, titles). Sans for information.
3. **Glass is a material, not a style.** Use glass only where content sits over imagery or the halo gradient. Never stack glass on glass more than 2 levels.
4. **Readable first.** WCAG AA minimum: 4.5:1 for body text, 3:1 for large text and glyphs. Support Dynamic Type up to AX3 in app screens.
5. **Native motion.** Use spring-based, short (0.25–0.5s) animations. No bounces on data.

### 7.2 Typography

Fonts are Apple system fonts only, so there is no licensing and they work in widgets:
- **Display:** New York (`.fontDesign(.serif)`). Used for dates, greetings, screen titles, event titles in hero contexts, and theme names.
- **Text/UI:** SF Pro (`.default`).
- **Numerals:** SF Pro Rounded (`.rounded`) for big times/timers/dates in grids, always `.monospacedDigit()`.

| Token | Font | Size / Weight | Line height | Tracking | Text style mapping (Dynamic Type) |
|---|---|---|---|---|---|
| `display.xl` | New York | 44 / Regular | 48 | −0.5 | `.largeTitle` relative |
| `display.l` | New York | 34 / Regular | 40 | −0.3 | `.largeTitle` |
| `display.m` | New York | 24 / Medium | 30 | −0.2 | `.title2` |
| `display.s` | New York | 20 / Medium | 25 | 0 | `.title3` |
| `headline` | SF Pro | 17 / Semibold | 22 | −0.2 | `.headline` |
| `body` | SF Pro | 17 / Regular | 22 | −0.2 | `.body` |
| `callout` | SF Pro | 16 / Regular | 21 | −0.2 | `.callout` |
| `subhead` | SF Pro | 15 / Regular | 20 | −0.1 | `.subheadline` |
| `footnote` | SF Pro | 13 / Regular | 18 | 0 | `.footnote` |
| `caption` | SF Pro | 12 / Medium | 16 | 0 | `.caption` |
| `caption.upper` | SF Pro | 11 / Semibold | 13 | +1.2, uppercase | `.caption2` |
| `numeric.hero` | SF Pro Rounded | 76 / Ultralight | 80 | −1 | fixed, scales with `.dynamicTypeSize` up to `.xxxLarge` |
| `numeric.l` | SF Pro Rounded | 34 / Light | 38 | −0.5 | `.largeTitle` |
| `numeric.m` | SF Pro Rounded | 20 / Medium | 24 | 0 | `.title3` |

Implement as `enum HaloFont` with `static func font(_ token:) -> Font` using `Font.system(size:weight:design:)` combined with `@ScaledMetric`, or `.system(.title2, design: .serif)` where sizes match text styles.

Widget typography: in widgets, use **text-style-based** fonts (`.system(.headline, design: .serif)`) so widgets follow the system's widget font scaling. Never go below 11pt.

### 7.3 Spacing (4pt base)

| Token | Value | Use |
|---|---|---|
| `space.0_5` | 2 | Hairline gaps, dot offsets |
| `space.1` | 4 | Icon-label tight |
| `space.2` | 8 | Inside chips, row internal |
| `space.3` | 12 | Card internal small, list row vertical |
| `space.4` | 16 | Screen margins, card padding |
| `space.5` | 20 | Card padding (hero) |
| `space.6` | 24 | Section spacing |
| `space.8` | 32 | Major section spacing |
| `space.10` | 40 | Onboarding vertical rhythm |
| `space.12` | 48 | Hero top spacing |

Widget padding: use the system default content margins (`.contentMarginsDisabled()` **not** used). Inside widgets, use `space.2`/`space.3` only.

### 7.4 Radius

All corner shapes use `RoundedRectangle(cornerRadius:, style: .continuous)`.

| Token | Value | Use |
|---|---|---|
| `radius.xs` | 6 | Event blocks in week grid, tiny tags |
| `radius.s` | 10 | Chips, segmented items, small thumbnails |
| `radius.m` | 16 | Standard cards, inputs, rows-as-cards |
| `radius.l` | 22 | Hero cards, glass cards, plan cards |
| `radius.xl` | 32 | Sheets' inner hero media, phone-mock screen |
| `radius.full` | 999 | Capsules, buttons, rings |
| Widgets | `ContainerRelativeShape()` | Always. Never hard-code widget corner radius. |

### 7.5 Shadow

Shadows are subtle and warm. Shadow color derives from the theme `shadowTint`, not pure black.

| Token | Spec (light themes) | Dark themes |
|---|---|---|
| `shadow.none` | — | — |
| `shadow.soft` | y 2, blur 8, `shadowTint` @ 6% | none (use border instead) |
| `shadow.card` | y 8, blur 24, `shadowTint` @ 8% + y 1, blur 2, @ 4% | 1pt `hairline` border |
| `shadow.float` | y 16, blur 40, `shadowTint` @ 12% | y 16, blur 40, black @ 40% |
| `shadow.glow` | accent @ 25%, blur 24, y 0 | accent @ 35%, blur 28 | Only for the active focus ring and the primary CTA pressed state |

Never use shadows inside widgets. The system handles widget elevation.

### 7.6 Glass rules

- **iOS 26+:** use the system `.glassEffect(.regular, in: shape)` for floating controls (tab bar, toolbars, Focus controls, Studio control tray). Use `.glassEffect(.regular.tint(theme.accent.opacity(0.15)))` only on the primary floating CTA.
- **iOS 18–25 fallback:** `.background(.ultraThinMaterial, in: shape)` + 0.5pt inner stroke `glassStroke` (white @ 35% light / white @ 12% dark) + `shadow.soft`.
- **Content cards** (Today cards, rows) are *not* glass by default. They are `surface` fills. Exception: `GlassCard.hero` (Next event) sits over the halo gradient.
- Text on glass must use `ink` / `ink2`. Never put accent-colored body text on glass.
- Max 2 glass layers stacked. No glass inside glass inside a sheet.
- Reduce Transparency: replace all glass with `surfaceSolid` + `hairline` border.

### 7.7 Backgrounds — the Halo

`ThemeBackground` = `bg` fill + a single **halo**: a radial gradient centered at (0.5, −0.1) of the screen. It goes from `halo` color at 100% to transparent at radius 0.9×width. It is static, not animated (except the onboarding welcome, where it slowly breathes ±4% over 6s, disabled with Reduce Motion).

This is the only gradient in the app. No other decorative gradients.

### 7.8 Cards

| Card | Fill | Radius | Padding | Shadow | Use |
|---|---|---|---|---|---|
| `Card.standard` | `surface` | `radius.m` | `space.4` | `shadow.card` | Progress, focus entry, rituals |
| `Card.hero` (glass) | glass (7.6) | `radius.l` | `space.5` | `shadow.float` | Next event, paywall plan selected |
| `Card.inset` | `surfaceSunken` | `radius.m` | `space.3` | none | Nested info, form-like blocks |
| `Card.preview` | `surface` | `radius.l` | `space.3` | `shadow.card` | Lock Screen preview container |

Card header pattern: `caption.upper` label in `ink2`, optional trailing action in `accentInk` `subhead`.

### 7.9 Buttons and controls

| Style | Spec | Use |
|---|---|---|
| `Button.primary` | Capsule, height 54, fill `accent`, label `accentOn` `headline`. Pressed: scale 0.97 + `shadow.glow`. Disabled: 35% opacity. | One per screen max |
| `Button.secondary` | Capsule, height 50, fill `surface`, 1pt `hairline` border, label `ink` `headline` | Alternate actions |
| `Button.glass` | Capsule or circle, glass material (7.6), label `ink` | Floating controls, focus pause |
| `Button.text` | No fill, `accentInk` `subhead` semibold | "Not now", "See all", Restore |
| `Button.destructive` | text style, system red | Delete, End session confirm |
| `Chip` | Height 32, `radius.s`, `surface`/`surfaceSunken`, selected = `accent` fill + `accentOn` text | Type/size selectors |
| `Segmented` | System `Picker(.segmented)` tinted by accent | Day/Week/Month |
| Page dots | 6pt dots, `ink2` @ 30%. Active = 18×6 capsule `ink`. | Onboarding |
| Toggle | System `Toggle`, `.tint(accent)` | Settings |

Haptics: `.selection` on chips and segments, `.success` on ritual complete and purchase, `.impact(.soft)` on primary buttons. Respect the Settings Haptics toggle.

### 7.10 Iconography

- **SF Symbols only** in UI and widgets. Default weight `.regular`, `.light` for large decorative uses (≥ 28pt). Use `.hierarchical` rendering with accent where meaningful.
- No emoji in UI chrome. Users *may* use emoji in ritual names.
- App icon: a thin, off-center luminous ring (the "halo") over a pearl-to-blush field, with a tiny ruby dot at 2 o'clock (the "now" marker). Provide light, dark, and tinted variants (iOS 18+ icon appearances). The designer delivers the master. Codex uses a placeholder SVG → PNG set until then.

### 7.11 Reusable components (build these first)

| Component | Purpose |
|---|---|
| `ThemeBackground` | bg + halo |
| `HaloCard` (`.standard/.hero/.inset/.preview`) | Card containers |
| `HaloButton` (styles above) | Buttons as `ButtonStyle`s |
| `ProgressRing(progress:, lineWidth:, segments:)` | Day ring, ritual ring, focus ring |
| `MonthProgressBar(date:)` | Thin bar + label |
| `WeekStrip(selected:)` | 7-day strip used in widgets and Calendar |
| `MiniMonthGrid(month:, highlights:)` | Shared with widget |
| `AgendaRow(event:, style:)` | App + widget variants |
| `RitualChip`, `RitualRow` | |
| `LockScreenMock(preset:, wallpaper:, scenario:)` | Studio, onboarding, Today preview |
| `HomeScreenMock(preset:)` | Studio Home surface |
| `PhoneFrame` | Wraps mocks with device bezel (Dynamic Island cutout) |
| `PremiumChip` | "✦ Premium" capsule |
| `EmptyState(glyph:, title:, message:, action:)` | |

**Shared widget/app views:** widget views live in a shared Swift package target (`HaloUI`) so the app's Studio previews render the *exact same* SwiftUI views as the widget extension.

---

## 8. Theme System

### 8.1 Theme token model

```swift
struct HaloTheme: Identifiable, Hashable, Codable {
    let id: ThemeID                 // enum: pearlHalo, rubyGlass, ...
    let name: String
    let mood: String
    let isPremium: Bool
    let supportsDark: Bool          // has a dark variant
    let light: ThemePalette
    let dark: ThemePalette?         // nil => theme is dark-only or light-only
    let widgetStyle: WidgetStyle    // see 8.3
    let wallpapers: [WallpaperID]
}

struct ThemePalette: Hashable, Codable {
    let bg: HexColor          // screen background
    let halo: HexColor        // halo glow color
    let surface: HexColor     // card fill
    let surfaceSunken: HexColor
    let surfaceSolid: HexColor // reduce-transparency replacement for glass
    let ink: HexColor         // primary text
    let ink2: HexColor        // secondary text
    let ink3: HexColor        // tertiary / disabled
    let hairline: HexColor    // separators, borders
    let accent: HexColor      // fills, glyphs, rings
    let accentInk: HexColor   // accent used as TEXT (AA on bg & surface)
    let accentOn: HexColor    // text/icons on accent fill
    let accentSoft: HexColor  // tints, selected backgrounds
    let shadowTint: HexColor
}
```

Inject the active theme through `@Environment(\.haloTheme)`. The app theme (in-app UI) and widget themes are independent: each preset carries its own theme.

`supportsDark == true`: follow the system appearance unless Settings overrides. Dark-only themes ignore light mode in-app (they force `.preferredColorScheme(.dark)` on the theme-rendered regions; system sheets/alerts still follow system).

### 8.2 The eight themes

> Contrast rule: `accentInk` must be ≥ 4.5:1 against both `bg` and `surface`. Values below were chosen to satisfy this. Write a unit test that verifies contrast for every palette (Section 17).

#### Pearl Halo: *Free* · signature default
- **Mood:** soft morning light, quiet luxury, pearl and linen.
- **Typography feeling:** airy New York Regular at large sizes, generous tracking on captions.
- **Widget style:** `airy`: light hairline separators, no fills, numerals ultralight.
- **Best wallpaper pairing:** soft-focus pearl/linen textures, overcast skies, white florals.

| Token | Light | Dark |
|---|---|---|
| bg | `#F6F3EF` | `#121113` |
| halo | `#EADFD6` | `#2A2422` |
| surface | `#FFFFFF` | `#1C1A1C` |
| surfaceSunken | `#EFEBE5` | `#161416` |
| ink | `#1D1B1E` | `#F3F0EC` |
| ink2 | `#6B6670` | `#A8A2A6` |
| hairline | `#E3DDD5` | `#2C292C` |
| accent | `#9A8572` (warm pearl taupe) | `#C9B5A0` |
| accentInk | `#74604E` | `#D4C2AE` |
| accentOn | `#FFFFFF` | `#1D1B1E` |
| accentSoft | `#EFE6DC` | `#2B2520` |
| shadowTint | `#5A4636` | `#000000` |

#### Ruby Glass: *Free* · the shareable hero look
- **Mood:** jewel-box elegance, a single drop of red on frosted glass.
- **Typography feeling:** New York Medium titles, crisp SF Pro semibold labels, confident.
- **Widget style:** `glass`: frosted panels, ruby "now" markers, ruby month-progress fill.
- **Best wallpaper pairing:** frosted white/blush abstracts, red roses on cream, deep wine velvet (dark).

| Token | Light | Dark |
|---|---|---|
| bg | `#F7F1EF` | `#140B0D` |
| halo | `#F2D3D6` | `#3A1218` |
| surface | `#FFFFFF` | `#1F1215` |
| surfaceSunken | `#F1E7E5` | `#190E11` |
| ink | `#1E1214` | `#F7ECEC` |
| ink2 | `#6E5A5D` | `#B49EA1` |
| hairline | `#EADCDB` | `#33201F` |
| accent | `#B0152F` | `#E0324F` |
| accentInk | `#A3122B` | `#F0627A` |
| accentOn | `#FFFFFF` | `#FFFFFF` |
| accentSoft | `#F6DADF` | `#3B1219` |
| shadowTint | `#5A0E1B` | `#000000` |

#### Champagne Day: *Premium*
- **Mood:** golden hour, celebration, warm cream paper.
- **Typography feeling:** New York with slightly larger titles, a classic editorial magazine.
- **Widget style:** `editorial`: serif numerals in Home widgets, thin gold rules.
- **Best wallpaper pairing:** champagne silk, sunlit beige architecture, warm film photography.

| Token | Light | Dark |
|---|---|---|
| bg | `#FAF6EE` | `#15120C` |
| halo | `#F1E3C6` | `#33291A` |
| surface | `#FFFDF8` | `#1F1A12` |
| surfaceSunken | `#F2ECDF` | `#19150E` |
| ink | `#2A2418` | `#F6EFE1` |
| ink2 | `#76694F` | `#B9AB8E` |
| hairline | `#E8DEC9` | `#342B1D` |
| accent | `#B8925A` | `#D7B278` |
| accentInk | `#7F6131` | `#DDBB86` |
| accentOn | `#FFFFFF` | `#1A150C` |
| accentSoft | `#F3E7D1` | `#33291A` |
| shadowTint | `#6B5226` | `#000000` |

#### Graphite Focus: *Free* · dark-only
- **Mood:** studio at night, precise, distraction-free.
- **Typography feeling:** SF Pro-forward, New York used sparingly. Rounded numerals dominate.
- **Widget style:** `technical`: tabular numerals, dense agenda, bone-white accent.
- **Best wallpaper pairing:** black architecture, dark concrete, monochrome night cityscapes.

| Token | Dark only |
|---|---|
| bg | `#0E0F11` |
| halo | `#1F2226` |
| surface | `#17191C` |
| surfaceSunken | `#121316` |
| ink | `#F2F1EE` |
| ink2 | `#9A9DA3` |
| hairline | `#26292E` |
| accent | `#E6E1D6` (bone) |
| accentInk | `#E6E1D6` |
| accentOn | `#0E0F11` |
| accentSoft | `#24262A` |
| shadowTint | `#000000` |

#### Emerald Ritual: *Premium*
- **Mood:** botanical calm, morning tea, slow living.
- **Typography feeling:** New York Regular, softer weights, calm.
- **Widget style:** `organic`: rounded ritual rings, leaf-green fills, small gold details.
- **Best wallpaper pairing:** monstera shadows, deep green velvet, misty forests.

| Token | Light | Dark |
|---|---|---|
| bg | `#F2F4EF` | `#0B1712` |
| halo | `#D7E6DA` | `#173328` |
| surface | `#FFFFFF` | `#12211B` |
| surfaceSunken | `#E8ECE5` | `#0E1B16` |
| ink | `#14231C` | `#EAF2EC` |
| ink2 | `#5A6B62` | `#9DB2A6` |
| hairline | `#DCE3DA` | `#1F3329` |
| accent | `#0F6B4C` | `#3FAE84` |
| accentInk | `#0F6B4C` | `#5CC79C` |
| accentOn | `#FFFFFF` | `#0B1712` |
| accentSoft | `#D6E9DF` | `#163327` |
| detail (gold, decorative only) | `#B89A5E` | `#C9AD72` |
| shadowTint | `#0F3B2A` | `#000000` |

#### Rose Atelier: *Premium*
- **Mood:** Parisian dressing room, blush silk, handwritten notes.
- **Typography feeling:** New York italic accents for greetings (`.italic()`), delicate.
- **Widget style:** `atelier`: soft blush fills, rounded chips, italic serif day names.
- **Best wallpaper pairing:** blush peonies, pink marble, soft-focus portraits.

| Token | Light | Dark |
|---|---|---|
| bg | `#FBF3F1` | `#1A1113` |
| halo | `#F4D9D6` | `#3A2226` |
| surface | `#FFFFFF` | `#24181B` |
| surfaceSunken | `#F4E8E5` | `#1E1417` |
| ink | `#2B1C1E` | `#F8ECEB` |
| ink2 | `#7A6265` | `#BFA5A8` |
| hairline | `#EEDDDA` | `#3A2A2D` |
| accent | `#B5656B` | `#E09AA0` |
| accentInk | `#99474E` | `#E8AAAF` |
| accentOn | `#FFFFFF` | `#2B1C1E` |
| accentSoft | `#F6E1E1` | `#3A2427` |
| shadowTint | `#6B3238` | `#000000` |

#### Ivory Minimal: *Premium*
- **Mood:** gallery wall, paper and ink, nothing extra.
- **Typography feeling:** large New York numerals, tiny SF Pro labels, high contrast, lots of space.
- **Widget style:** `minimal`: no backgrounds, no dots, black ink only, accent = ink.
- **Best wallpaper pairing:** plain ivory, single-object still lifes, architectural white.

| Token | Light | Dark |
|---|---|---|
| bg | `#FBFAF6` | `#0F0F0E` |
| halo | `#F1EEE6` | `#1C1B19` |
| surface | `#FFFFFF` | `#181816` |
| surfaceSunken | `#F3F1EB` | `#131312` |
| ink | `#151515` | `#F5F3EE` |
| ink2 | `#6F6D68` | `#A3A09A` |
| hairline | `#E6E3DA` | `#2A2926` |
| accent | `#151515` | `#F5F3EE` |
| accentInk | `#151515` | `#F5F3EE` |
| accentOn | `#FBFAF6` | `#0F0F0E` |
| accentSoft | `#ECE9E1` | `#22211F` |
| shadowTint | `#2A2A2A` | `#000000` |

#### Midnight Gold: *Premium* · dark-only
- **Mood:** black-tie evening, hotel lobby at midnight, gold leaf.
- **Typography feeling:** New York Regular, wide-tracked uppercase captions, opulent but quiet.
- **Widget style:** `gilded`: gold hairlines, gold numerals, navy-black fields.
- **Best wallpaper pairing:** night skies, dark marble with gold veins, city lights bokeh.

| Token | Dark only |
|---|---|
| bg | `#0A0C14` |
| halo | `#1E2235` |
| surface | `#131726` |
| surfaceSunken | `#0E111C` |
| ink | `#F4EFE4` |
| ink2 | `#A7A291` |
| hairline | `#252A3D` |
| accent | `#D4AF6A` |
| accentInk | `#DDBC7E` |
| accentOn | `#0A0C14` |
| accentSoft | `#2A2618` |
| shadowTint | `#000000` |

### 8.3 Theme summary

| Theme | Tier | Modes | Widget style | Signature element |
|---|---|---|---|---|
| Pearl Halo | Free | L/D | airy | Taupe halo glow |
| Ruby Glass | Free | L/D | glass | Ruby "now" marker |
| Graphite Focus | Free | D | technical | Bone numerals |
| Champagne Day | Premium | L/D | editorial | Serif numerals, gold rules |
| Emerald Ritual | Premium | L/D | organic | Green ritual rings |
| Rose Atelier | Premium | L/D | atelier | Italic serif greetings |
| Ivory Minimal | Premium | L/D | minimal | Ink-only |
| Midnight Gold | Premium | D | gilded | Gold hairlines |

**Free plan = 3 themes:** Pearl Halo (light), Ruby Glass (signature accent, drives shares), Graphite Focus (dark). This gives every free user a light theme, a dark theme, and the shareable look.

### 8.4 `WidgetStyle` parameters

Themes alter widget layout through a small parameter set. This keeps widget code single-sourced.

```swift
struct WidgetStyle: Hashable, Codable {
    var numeralDesign: Font.Design      // .rounded | .serif | .default
    var numeralWeight: Font.Weight      // .ultraLight ... .medium
    var titleDesign: Font.Design        // .serif | .default
    var italicDayNames: Bool            // Rose Atelier
    var separator: SeparatorStyle       // .none | .hairline | .dot
    var nowMarker: NowMarker            // .dot | .bar | .ring
    var density: Density                // .airy (2 rows) | .regular (3) | .dense (3 + tighter)
    var lockScreenBackground: Bool      // use AccessoryWidgetBackground() on Lock Screen
    var progressStyle: ProgressStyle    // .bar | .dots | .ring
}
```

| Style | numeral | title | separator | nowMarker | density | LS bg | progress |
|---|---|---|---|---|---|---|---|
| airy | rounded/ultraLight | serif | hairline | dot | airy | off | bar |
| glass | rounded/light | serif | none | bar | regular | **on** | bar |
| editorial | serif/regular | serif | hairline | dot | regular | off | bar |
| technical | rounded/medium | default | none | bar | dense | on | dots |
| organic | rounded/regular | serif | dot | ring | regular | on | ring |
| atelier | serif/regular | serif (italic days) | dot | dot | airy | off | bar |
| minimal | serif/light | serif | none | bar | airy | off | bar |
| gilded | serif/regular | serif | hairline | ring | regular | on | bar |

### 8.5 Wallpapers

- Each theme ships with 3 paired wallpapers (MVP: **Ruby Glass, Pearl Halo, Graphite Focus** packs are free with 1 wallpaper each. Premium themes have 3 each). Total MVP: 3 free + 15 premium = 18 images, 1290×2796 HEIC, generated or licensed. Placeholder: procedural gradients + noise rendered with `ImageRenderer` until final art arrives.
- Wallpapers must keep the **top 45% calm** (clock area) and the **widget band (y 30–42%)** low-contrast so widgets stay legible.
- "Save to Photos" uses `PHPhotoLibrary.requestAuthorization(for: .addOnly)`.

---

## 9. Widget Design System

### 9.1 Widget catalog (kinds)

Use one `Widget` per **type**, each supporting multiple families. All use `AppIntentConfiguration` with a `PresetEntity` parameter (default "Active preset"), plus type-specific parameters.

| Kind | Families | Config parameters | Tier |
|---|---|---|---|
| `TodayAgendaWidget` | accessoryInline, accessoryRectangular, systemSmall, systemMedium, systemLarge | preset, calendars, includeAllDay | Free (Small/Rect/Inline), Premium (Medium/Large) |
| `MonthProgressWidget` | accessoryInline, accessoryCircular, accessoryRectangular, systemSmall | preset | Free |
| `WeekStripWidget` | accessoryRectangular, systemMedium | preset, calendars | Free (Rect), Premium (Medium) |
| `MiniCalendarWidget` | systemSmall, systemLarge | preset, calendars | Free (Small), Premium (Large) |
| `HabitStreakWidget` | accessoryCircular, accessoryRectangular, systemSmall | preset, ritual | **Premium** |
| `FocusSessionWidget` | accessoryCircular, accessoryRectangular, systemSmall | preset, defaultDuration | **Premium** |
| `CountdownWidget` | accessoryInline, accessoryCircular, accessoryRectangular, systemSmall | preset, countdown (entity) | Free (1 countdown), Premium (unlimited) |
| `DailyRitualWidget` | accessoryCircular, accessoryRectangular, systemSmall, systemMedium | preset, rituals (≤4) | Free (Circ/Rect/Small), Premium (Medium + interactive) |

**Premium gating inside widgets:** when a free user installs a premium family, render a tasteful locked state: theme-styled blurred sample + "✦ Unlock in Halo Day" with a `widgetURL` to `haloday://paywall?source=widget_{kind}`. Do not render a broken or empty widget.

Entitlement is written to the App Group (`entitlement.json`) by the app on every StoreKit transaction update. Widgets read it. If it is unknown, default to free.

### 9.2 Rendering modes (must implement)

Read `@Environment(\.widgetRenderingMode)`:

| Mode | Where | Rules |
|---|---|---|
| `.vibrant` | Lock Screen accessories, StandBy night | No color. Hierarchy via **opacity levels only**: primary 100%, secondary 60%, tertiary 35%. Use `.widgetAccentable()` on the "now" marker and progress fills. Optional `AccessoryWidgetBackground()` per `WidgetStyle.lockScreenBackground`. |
| `.fullColor` | Home Screen default, StandBy day | Full theme palette via `containerBackground(for: .widget) { ThemeWidgetBackground() }` |
| `.accented` | Home Screen tinted/clear modes (iOS 18+/26) | Mark accent elements with `.widgetAccentable()`. Background is removed by the system. Ensure layout still reads with ink at system tint. Use `.widgetAccentedRenderingMode(.desaturated)` (iOS 18+) for any image. |

**Studio vibrant simulation:** to preview Lock Screen widgets honestly in-app, render the widget view with `.environment(\.widgetRenderingMode, .vibrant)` (where settable) or a `vibrantPreview` flag that maps all theme colors to white (dark wallpaper) or near-black (light wallpaper) at the opacity tiers above, with `.blendMode(.plusLighter)` on dark wallpapers. A side-by-side "As iOS shows it" label sits under the mock.

### 9.3 Type × size matrix

| Type \ Family | Inline | Circular | Rectangular | Small | Medium | Large |
|---|---|---|---|---|---|---|
| Today Agenda | ✓ | — | ✓ | ✓ | ✓ | ✓ |
| Month Progress | ✓ | ✓ | ✓ | ✓ | — | — |
| Week Strip | — | — | ✓ | — | ✓ | — |
| Mini Calendar | — | — | — | ✓ | — | ✓ |
| Habit Streak | — | ✓ | ✓ | ✓ | — | — |
| Focus Session | — | ✓ | ✓ | ✓ | — | — |
| Countdown | ✓ | ✓ | ✓ | ✓ | — | — |
| Daily Ritual | — | ✓ | ✓ | ✓ | ✓ | — |

### 9.4 Component rules (widgets)

1. **Max content:** Rectangular = 3 text lines. Small = 4 lines + 1 graphic. Medium = 2 columns. Large = 6 agenda rows + header.
2. **Truncation:** titles `.lineLimit(1)` with `.truncationMode(.tail)`. Never truncate times.
3. **Time formatting:** respect the 12/24h locale. Use `Text(date, style: .time)` to avoid timeline churn.
4. **Self-updating text:** "in 25 min" uses `Text(eventStart, style: .relative)` (with a "NOW" fallback entry at start). Timers use `Text(timerInterval:countsDown:)`.
5. **Privacy:** support `.privacySensitive()` on event titles. When the device is locked and the user enables "Hide details on Lock Screen" in Settings (Future toggle, but mark views now), titles redact to "Busy".
6. **Accessibility:** every widget gets an `.accessibilityLabel` summarizing it, e.g. "Next: Design review at 10:30, in 25 minutes."
7. **Deep links:** whole-widget `widgetURL`. Medium/Large rows use `Link` per row → event detail.
8. **Placeholder & snapshot:** `placeholder` uses redacted fixtures. `snapshot` (gallery) uses beautiful **sample data** ("Design review", "Pilates", "Dinner with Mai") so the widget gallery looks premium even before calendar permission.
9. **Containers:** `.containerBackground(for: .widget)` is required. Content margins use system defaults.
10. **No images** in accessory families except SF Symbols.

### 9.5 Timeline strategy

| Widget | Entries |
|---|---|
| Agenda / Week / Mini | One entry at each event start and end over the next 24h (max 30), + midnight rollover. Policy `.after(nextMidnight)`. |
| Month Progress | One entry at midnight. Policy `.atEnd`. |
| Countdown | One entry at midnight (days change). Use the relative style when < 24h. |
| Ritual / Habit | Single entry now + midnight reset. Reloaded by intents and the app on change. |
| Focus | Idle: single entry. Running: entry at start + end, with the timer text self-updating. |

The app triggers `WidgetCenter.shared.reloadAllTimelines()` on: `EKEventStoreChanged`, theme/preset change, ritual change, entitlement change, day-window change, `significantTimeChange`.

---

## 10. Lock Screen Widget Concepts

Dimensions below are for reference (iPhone 15/16 Pro). Never hard-code them: use `GeometryReader`-free layouts and let the family size the view.

### 10.1 Accessory designs

**Inline (`accessoryInline`)**: a single line above the clock. Only `Text` + one SF Symbol render. The system picks the font.

| Type | Content example |
|---|---|
| Agenda | `􀐫 Design review · 10:30` (symbol `circle.circle`) / `Free until 14:00` |
| Month Progress | `October · 16%` |
| Countdown | `12 days · Lisbon` |

**Circular (`accessoryCircular`)**: ~72×72pt.

| Type | Design |
|---|---|
| Month Progress | `Gauge(value:) .gaugeStyle(.accessoryCircularCapacity)`. Center: day numeral (rounded/serif per style) over "OCT" caption. |
| Habit Streak | Ring = today's ritual completion. Center: streak count + tiny `sparkle`. |
| Daily Ritual | Segmented ring (one segment per ritual, max 6). Center: ritual glyph of the next incomplete ritual. |
| Focus | Idle: `timer` glyph + "50". Running: `ProgressView(timerInterval:)` circular + remaining min. |
| Countdown | Big number of days + "DAYS" caption (≤ 99; above that show "3 mo"). |

**Rectangular (`accessoryRectangular`)**: ~172×76pt, max 3 lines. Hero widget:

```
Today Agenda (regular density)
┌────────────────────────────┐
│ ▍NOW  Design review        │  ← line 1: widgetAccentable bar + headline (serif or sans per style)
│  10:30–11:15 · ends 18 min │  ← line 2: secondary 60%
│  13:00  Lunch with Mai     │  ← line 3: next event, tertiary 60%
└────────────────────────────┘

Month Progress
┌────────────────────────────┐
│ OCTOBER            16%     │
│ ▓▓▓▓░░░░░░░░░░░░░░░░░░     │  ← Gauge(.linearCapacity) accentable
│ 26 days left · Day 5       │
└────────────────────────────┘

Week Strip
┌────────────────────────────┐
│ M  T  W  T  F  S  S        │
│ 4 [5] 6  7  8  9 10        │  ← today in accented capsule
│ •  ••    •     •           │  ← event dots (max 3)
└────────────────────────────┘

Daily Ritual
┌────────────────────────────┐
│ RITUALS              3/5   │
│ ◉ Water ◉ Journal ◯ Read   │  ← glyphs + names, wrap to 2 rows
│ ◯ Skin  ◯ Walk             │
└────────────────────────────┘

Focus (running)
┌────────────────────────────┐
│ 􀐱 FOCUS · Deep work       │
│ 32:14                      │  ← Text(timerInterval:) rounded medium
│ ▓▓▓▓▓▓▓▓▓░░░░ ends 11:20   │
└────────────────────────────┘
```

### 10.2 Starter presets (onboarding step 6 + Studio defaults)

| Preset | Theme | Inline | Bottom row |
|---|---|---|---|
| **Agenda** | Ruby Glass | Month Progress | Rect: Today Agenda + Circ: Month Progress + Circ: Daily Ritual |
| **Ritual** | Pearl Halo | Countdown (if any) or Month Progress | Rect: Daily Ritual + Rect: Week Strip |
| **Minimal** | Graphite Focus | Today Agenda | Circ: Month Progress + Circ: Daily Ritual + Circ: Focus + Circ: Countdown |

Presets can be saved from Studio. Premium-only widget types in a starter preset are swapped for free equivalents on the free tier.

### 10.3 Home Screen designs

**Small (systemSmall)** · Today Agenda
```
┌────────────────┐
│ MON            │ caption.upper accentInk
│ 5              │ numeral 44 (style)
│ ▍Design review │ headline 1 line, accent bar
│  10:30 · 25 min│ footnote ink2
│ +3 more today  │ caption ink3
└────────────────┘
```

**Small** · Mini Calendar: month name in serif, 6×7 grid in rounded 11pt, today = accent filled circle with `accentOn` numeral, event-day dots under numerals.

**Small** · Month Progress: big percentage numeral, vertical "OCTOBER" label, bar at the bottom.

**Medium (systemMedium)** · Today Agenda
```
┌────────────────────────────────────────┐
│ MONDAY             │ ▍10:30 Design review│
│ 5 Oct              │   Studio B          │
│ ▓▓▓░░░ 16% Oct     │  13:00 Lunch w/ Mai  │
│ ◉◉◯◯◯ rituals      │  16:00 Pilates       │
└────────────────────────────────────────┘
```
Left column 40% (date, month progress, ritual dots). Right column 60% (3 agenda rows).

**Medium** · Daily Ritual (Premium, interactive): 4 ritual buttons in a row (`Button(intent: ToggleRitualIntent)`), each a 48pt circle with glyph, name below, filled when done, + header "3 of 5 · Day streak 12".

**Large (systemLarge)** · Today Agenda: header (date serif + greeting-less day summary "5 events · first at 09:00"), Week Strip, 6 agenda rows with time column, footer with month progress.

**Large** · Mini Calendar: full month grid + selected day (today) agenda for 3 rows below.

### 10.4 Legibility guarantees

- Lock Screen: rely on vibrant rendering. Test on 4 reference wallpapers: pure white, pure black, busy photo light, busy photo dark. Provide these as Studio "preview states".
- Home Screen fullColor: the widget background is always the theme `surface` (opaque), never transparent, so text contrast is guaranteed.

---

## 11. Live Activity and Dynamic Island Concepts

### 11.1 Attributes

```swift
struct HaloActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var phase: Phase              // .running, .paused, .ended
        var startDate: Date
        var endDate: Date
        var pausedRemaining: TimeInterval?  // when paused
        var subtitle: String?         // e.g. "Studio B" or next ritual
    }
    var kind: Kind                    // .focus, .eventCountdown, .ritual
    var title: String                 // "Deep work", "Design review"
    var themeID: ThemeID              // resolved to colors in the widget extension
    var glyph: String                 // SF Symbol name
}
```

Payload stays under 4 KB (no images, no long notes).

### 11.2 Lock Screen expanded (banner)

Full color is allowed here. Use `.activityBackgroundTint(theme.surface.opacity(0.85))` and `.activitySystemActionForegroundColor(theme.accent)`.

```
Focus (running)
┌───────────────────────────────────────────┐
│ ◯ HALO DAY · FOCUS                 ends 11:20 │ caption.upper ink2
│ Deep work                           32:14  │ serif 20 ink · rounded 34 accent (timer)
│ ▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░                      │ ProgressView(timerInterval:) accent on hairline
│ Next: Design review at 11:30               │ footnote ink2
└───────────────────────────────────────────┘

Event countdown
┌───────────────────────────────────────────┐
│ ● WORK                          in 18 min  │
│ Design review                       10:30  │
│ Studio B                                   │
└───────────────────────────────────────────┘

Ritual (active, e.g. "Morning routine" 3 steps)
┌───────────────────────────────────────────┐
│ ◌ MORNING RITUAL                    2 / 3  │
│ Journal                         12:00 left │
│ ◉ Water  ◉ Stretch  ◯ Journal               │
└───────────────────────────────────────────┘
```

Paused focus: timer replaced with static remaining time + "Paused" chip. Interactive buttons (iOS 17+ `Button(intent:)`): **Pause/Resume** and **End** on the focus banner.

### 11.3 Dynamic Island

| Presentation | Focus | Event countdown | Ritual |
|---|---|---|---|
| **Compact leading** | Theme-accent `timer` glyph | Calendar color dot + `calendar` glyph | Ritual glyph |
| **Compact trailing** | `Text(timerInterval:)` rounded, monospaced, max width 52pt (e.g. `32:14`) | `Text(start, style: .relative)` shortened ("18m") | "2/3" |
| **Minimal** | Circular `ProgressView(timerInterval:)` with accent tint (the "halo" ring) | Ring that depletes toward start | Ring segmented by steps |
| **Expanded leading** | Glyph in a 36pt accent-soft circle + "Focus" caption | Calendar dot + calendar name | Glyph + "Ritual" |
| **Expanded trailing** | Large timer, rounded 28 | "in 18 min" | "2 / 3" |
| **Expanded center** | Title (serif, 1 line) | Event title | Current step name |
| **Expanded bottom** | Progress bar + [Pause] [End] buttons (glass capsules) | Time range · location + [Open] | Step chips |

`keylineTint` = theme accent. Use Dynamic Island colors on black: the Island is always black, so use the theme's **dark** palette accent (e.g. Ruby `#E0324F`, Gold `#D4AF6A`).

### 11.4 Lifecycle rules

- Focus: start on "Begin focus". Update on pause/resume. End with `.final` state and `dismissalPolicy: .after(now + 15 min)`.
- Event countdown: start ≤ 60 min before the event. At event start, update to phase `.running` with "Now · ends 11:15" until the end, then end with `.immediate` dismissal.
- Only **one** Halo Live Activity at a time. Starting a new one ends the previous.
- Respect `ActivityAuthorizationInfo().areActivitiesEnabled`. If disabled, show an inline explanation + Settings link.
- `Info.plist`: `NSSupportsLiveActivities = YES`. `NSSupportsLiveActivitiesFrequentUpdates` is not needed.

---

## 12. Premium Monetization Model

### 12.1 Plans (StoreKit 2)

| Product ID | Type | Price (US) | Notes |
|---|---|---|---|
| `co.haloday.premium.yearly` | Auto-renew, group `premium` | $24.99/yr | 7-day free trial (intro offer), **default selected** |
| `co.haloday.premium.monthly` | Auto-renew, group `premium` | $3.99/mo | No trial |
| `co.haloday.premium.lifetime` | Non-consumable | $49.99 | For subscription-averse users |

Prices are recommendations, set in App Store Connect. The app always shows `displayPrice`.

### 12.2 Free vs Premium

| Feature | Free | Premium |
|---|---|---|
| Calendar sync (EventKit) | ✓ | ✓ |
| Today, Calendar (Day/Week/Month) | ✓ | ✓ |
| Themes | Pearl Halo, Ruby Glass, Graphite Focus | All 8 |
| Lock Screen widgets | Agenda, Month Progress, Week Strip, Mini Calendar (small), Countdown (1), Daily Ritual | + Habit Streak, Focus Session |
| Home Screen widgets | Small sizes | + Medium & Large, interactive ritual widget |
| Widget presets | 1 | Unlimited + "Active preset" switching |
| Rituals | Up to 3 | Unlimited + 12-week history |
| Reminders | Event reminders, ritual reminders | + Morning brief |
| Focus | In-app timer + end notification | + Live Activities & Dynamic Island |
| Event countdown Live Activity | — | ✓ |
| Theme editor (accent + numeral style tweaks) | — | ✓ (**Future**: shipped in v1.1, listed on paywall as "coming soon" only if it ships within 60 days; otherwise omit from paywall) |
| Wallpaper packs | 1 per free theme | All packs |

> **Note:** The brief lists "Theme editor" as Premium. It is **out of MVP** (Section 15). Do **not** advertise it on the v1 paywall. Add the bullet when it ships. This keeps the paywall honest.

### 12.3 Paywall triggers (sources)

`onboarding_theme`, `studio_theme`, `studio_widget_type`, `studio_size`, `preset_limit`, `ritual_limit`, `focus_live_activity`, `event_countdown`, `widget_locked_{kind}`, `settings`, `wallpaper`. Log the source locally for later analytics.

### 12.4 Entitlement logic

- `EntitlementStore` (an `@Observable` actor) listens to `Transaction.updates` on launch and checks `Transaction.currentEntitlements`.
- Premium = any active subscription in group `premium` **or** a lifetime purchase.
- The store writes `{"isPremium": bool, "updatedAt": iso8601}` to the App Group and reloads widget timelines on change.
- Grace period / billing retry counts as premium (StoreKit handles this through `currentEntitlements`).
- Use a StoreKit configuration file (`HaloDay.storekit`) for local testing.

---

## 13. App Store Positioning

- **App name:** Halo Day: Lock Screen Planner
- **Subtitle (30 chars):** `Calendar widgets, beautifully` (29)
- **Category:** Productivity (primary), Lifestyle (secondary)
- **Keywords (100 chars):** `lock screen,widget,calendar,aesthetic,planner,habit,focus,timer,agenda,countdown,theme,daily,ritual`
- **Promotional text:** "New: Midnight Gold. A black-tie theme for your Lock Screen."

**Description (opening):**
> Your day, beautifully on display.
>
> Halo Day turns your calendar, rituals, and focus time into elegant widgets for your Lock Screen and Home Screen. See what's next without unlocking. Keep your routines in view. Make every glance a little more beautiful.
>
> • Lock Screen widgets for your agenda, month progress, week, rituals and countdowns
> • Eight luxury themes, from Pearl Halo to Midnight Gold
> • Widget Studio: design, preview and save your perfect setup
> • Focus sessions on your Lock Screen and Dynamic Island
> • Rituals with gentle streaks
> • Private by design: your calendar never leaves your iPhone

**Screenshots (6.9" set, 6 frames)**, each with a serif headline on the theme `bg`:
1. "Your day, beautifully on display." Hero Lock Screen in Ruby Glass.
2. "See what's next. Without unlocking." Rectangular agenda close-up.
3. "Eight luxury themes." Fan of 4 phones (Pearl, Champagne, Emerald, Midnight Gold).
4. "Design it in Widget Studio." Studio screen.
5. "Focus, right on your Dynamic Island." Island expanded + Lock Screen banner.
6. "Rituals, kept gently." Rituals screen + ritual widget.

**App Privacy label:** Data Not Collected (MVP has no analytics SDK and no server).

**Review notes** (for App Review): explain that the app does not modify the Lock Screen itself and only provides WidgetKit widgets and Live Activities. Provide steps to see the widgets.

---

## 14. Copywriting

Voice: calm, warm, concise, slightly editorial. Second person. No exclamation marks except in success moments (max one). Never guilt-trip ("You broke your streak!" ✗ → "A fresh start today." ✓).

### 14.1 Onboarding

| # | Title | Body | CTA | Secondary |
|---|---|---|---|---|
| 1 | Halo Day | Your day, beautifully on display. | Begin | — |
| 2 | Your day, at a glance | Your schedule, rituals and focus time on the Lock Screen. Glance, and go. | Continue | — |
| 3 | Choose your style | Pick a look. You can change it anytime. | Continue with {Theme} | — |
| 4 | Bring in your calendar | Halo Day reads your calendar to show what's next. It stays on your iPhone. Always. | Connect Calendar | Not now |
| 5 | Gentle reminders | A quiet nudge before events and rituals. Never noisy. | Allow reminders | Not now |
| 6 | Your first Halo | Choose a starting layout. Make it yours in Studio. | Save my Halo | — |

Theme carousel caption under each card = theme mood line (Section 8.2).
Premium preview chip: "✦ Premium preview".
Soft gate on save (premium theme chosen): Title "Keep {Theme}?" Body "{Theme} is part of Halo Day Premium. Start a free trial, or continue with Pearl Halo. It's lovely too." Buttons: "Try Premium free" / "Continue with Pearl Halo".

`NSCalendarsFullAccessUsageDescription`: "Halo Day shows your events in the app and in your widgets. Your calendar stays on your iPhone."
`NSPhotoLibraryAddUsageDescription`: "Halo Day saves wallpapers you choose to your Photos."

### 14.2 Today

- Greetings: "Good morning", "Good afternoon", "Good evening", "Still up"
- Next label: "NEXT · in {relative}" / "NOW · ends in {relative}"
- Wrap-up: "That's a wrap for today." + "Tomorrow starts with {title} at {time}."
- Preview card: "Your Halo · {preset}" / "Edit"
- Focus card: "Focus" / "Start {n} min"

### 14.3 Paywall

- **Headline:** Make every glance beautiful.
- **Subheadline:** All themes, advanced widgets, and Live Activities. Your day, at its most beautiful.
- **Feature bullets:**
  - ✦ All 8 luxury themes, from Champagne Day to Midnight Gold
  - ✦ Advanced widgets: Habit Streak, Focus, and large Home Screen layouts
  - ✦ Unlimited widget presets: switch your look in a tap
  - ✦ Focus sessions on your Lock Screen and Dynamic Island
  - ✦ Event countdowns as Live Activities
  - ✦ Premium wallpaper packs, paired to every theme
  - ✦ Unlimited rituals with streak history
- **Plan labels:** "Yearly" + badge "Best value" · "Monthly" · "Lifetime" + caption "Pay once. Yours forever."
- **CTA:** Yearly + eligible: "Start 7-day free trial" · Yearly, not eligible: "Continue with Yearly" · Monthly: "Subscribe for {price}/month" · Lifetime: "Buy once for {price}"
- **Trial text (under CTA):** "Free for 7 days, then {price}/year. Cancel anytime in Settings. We'll remind you 2 days before your trial ends." (Schedule a local notification at trial day 5 if notifications are authorized. Honesty feature.)
- **Restore:** "Restore Purchase"
- **Restore results:** success "Welcome back. Premium is restored." · nothing found "We couldn't find a previous purchase for this Apple ID."
- **Footer:** "Terms" · "Privacy"
- **Success toast:** "Welcome to Halo Day Premium."
- **Error:** "The purchase didn't go through. You haven't been charged."

### 14.4 Settings

| Item | Copy |
|---|---|
| Premium row (free) | "Upgrade to Premium" / footnote "All themes, advanced widgets, Live Activities." |
| Premium row (subscribed) | "Halo Day Premium" / "Renews {date}" or "Lifetime" |
| Name | "Your first name" / footer "Used only for your greeting." |
| Day window | "Your day" / footer "Day progress is measured between these times." |
| Calendar access denied | "Calendar access is off. Turn it on in Settings to see your events." / "Open Settings" |
| Morning brief | "Morning brief" / footer "A short summary of your day at the time you choose." |
| Countdown before events | footer "Starts when Halo Day refreshes in the background, so it's usually on time and occasionally a little late. You can always start one from an event." |
| Live Activities off (system) | "Live Activities are turned off for Halo Day in iOS Settings." |
| Privacy | "Your calendar never leaves your iPhone. Halo Day has no accounts, no tracking, and no servers." |
| Refresh widgets | "Refresh widgets now" / toast "Widgets refreshed." |

### 14.5 Empty states

| Context | Title | Message | Action |
|---|---|---|---|
| Today · no calendar access | Your day, waiting | Connect your calendar to see what's next, here and on your Lock Screen. | Connect Calendar |
| Today · no events | An open day | Nothing on the calendar. Make room for something good. | Start a focus session |
| Today · all done | That's a wrap for today. | Tomorrow starts with {title} at {time}. | — |
| Calendar · no events on day | — | Nothing scheduled. A rare, open day. | — |
| Rituals · none | Begin a ritual | Small, daily things. Water, a page, a walk. | Add your first ritual |
| Rituals · all done | All done today | Beautifully kept. See you tomorrow. | — |
| Focus · no sessions this week | Make space to focus | Choose a length and begin. | Begin focus |
| Presets · none | No presets yet | Design a look in Studio and save it here. | Open Studio |
| Countdown · none | Count down to something | A trip, a birthday, a launch. | Add countdown |
| Widget (locked) | ✦ Unlock in Halo Day | — | (widgetURL → paywall) |
| Widget (no calendar access) | Connect Calendar | Open Halo Day to show your agenda. | (widgetURL → onboarding step 4) |
| Streak reset | A fresh start | Every day is a new one. | — |

### 14.6 How to add widgets (sheet)

**Lock Screen**
1. "Touch and hold your Lock Screen, then tap **Customize**."
2. "Choose **Lock Screen**, then tap the widget area under the clock."
3. "Find **Halo Day** and tap the widgets you want."
4. "Tap a widget to choose a preset, then tap **Done**."
Footer: "Tip: Halo Day widgets follow your Active preset unless you choose another."

**Home Screen**
1. "Touch and hold an empty spot on your Home Screen."
2. "Tap **Edit**, then **Add Widget**."
3. "Search for **Halo Day** and pick a size."
4. "Tap **Add Widget**, then Done."

**Set a wallpaper**
1. "Save a wallpaper from your theme."
2. "Open **Photos**, select it, tap **Share**, then **Use as Wallpaper**."
3. "Adjust, then tap **Add** or **Done**."

> iOS menu wording changes between versions. Keep these strings in one place (`HowToSteps.swift`) for easy updates.

---

## 15. MVP Scope vs Future Scope

### 15.1 MVP (v1.0)

| Area | Included |
|---|---|
| Onboarding | All 6 screens, soft gate, how-to sheet |
| Today | All elements in 6.2 |
| Calendar | Day/Week/Month, read-only event detail, source filter, empty states |
| Studio | Lock Screen + Home surfaces, slot editor, all 8 types, theme/data/preview states, vibrant simulation, presets, how-to |
| Themes | 8 themes, gallery, detail, wallpapers (placeholder art acceptable for TestFlight) |
| Rituals | CRUD, check/count, schedules, reminders, streaks, 12-week grid |
| Focus | Dial, active session, completion, session log, Live Activity + Island |
| Live Activities | Focus + event countdown (manual from event detail + best-effort auto) |
| Widgets | All kinds in 9.1, all rendering modes, locked states, interactive ritual + focus buttons |
| Notifications | Event reminders, ritual reminders, morning brief, trial reminder |
| Paywall | 3 products, StoreKit 2, restore, entitlement in App Group |
| Settings | Sections 1–10 in 6.9 (excluding Future items) |
| Accessibility | Dynamic Type, VoiceOver labels, Reduce Motion, Reduce Transparency, contrast tests |
| Localization | English only, all strings in String Catalog |

### 15.2 Future (do not build in v1, leave seams)

| Feature | Seam to leave |
|---|---|
| Theme editor (custom accent, numeral style) | `HaloTheme` is Codable; `ThemeID.custom(UUID)` reserved |
| Event creation/editing | `CalendarService` protocol has no write methods yet. Add them later. |
| Shareable "Halo card" image export | `LockScreenMock` must render cleanly in `ImageRenderer` (avoid materials that don't render; use `surfaceSolid` path when `isExporting`) |
| Push-to-start Live Activities (server) | `LiveActivityService` behind a protocol |
| Control Center controls (iOS 18 ControlWidget) | none |
| Hide details on Lock Screen toggle | `.privacySensitive()` already applied |
| iCloud sync of rituals/presets (CloudKit) | SwiftData models avoid unique constraints, and all properties are optional or defaulted (CloudKit-compatible) |
| Focus statistics charts | `FocusSession` model stores start/end/label |
| Alternate app icons | Settings row hidden |
| Weather in inline widget | none |
| Apple Watch complications | widget views in `HaloUI` package |
| Localization (VI, JA, KO, FR, ES) | String Catalog |
| Privacy-safe analytics (e.g. TelemetryDeck) | `Analytics.log(_:)` no-op facade exists |

---

## 16. Technical Architecture (implementation notes)

### 16.1 Targets & requirements

- **Xcode:** latest stable. **Swift 6** language mode, strict concurrency.
- **Deployment target:** **iOS 18.0**. Use `if #available(iOS 26, *)` for Liquid Glass APIs (`glassEffect`).
- **Targets:**
  - `HaloDay` (app)
  - `HaloDayWidgets` (Widget extension: all widgets + Live Activity UI)
  - `HaloKit` (local Swift package): `HaloCore` (models, services, theme tokens, no UI) and `HaloUI` (shared SwiftUI views used by the app and widgets)
  - `HaloDayTests`, `HaloKitTests`
- **App Group:** `group.co.haloday.shared`
- **Capabilities:** App Groups, Push Notifications not required, In-App Purchase.
- **Info.plist:** `NSCalendarsFullAccessUsageDescription`, `NSPhotoLibraryAddUsageDescription`, `NSSupportsLiveActivities`, `UIBackgroundModes: fetch` + `BGTaskSchedulerPermittedIdentifiers: co.haloday.refresh`, URL scheme `haloday`.

### 16.2 Folder structure

```
HaloDay/
├── App/ (HaloDayApp.swift, RootView, TabRouter, DeepLink)
├── Features/
│   ├── Onboarding/
│   ├── Today/
│   ├── Calendar/
│   ├── Studio/
│   ├── Themes/
│   ├── Rituals/
│   ├── Focus/
│   ├── Paywall/
│   └── Settings/
├── Resources/ (Assets.xcassets, Localizable.xcstrings, HaloDay.storekit, Wallpapers/)
HaloDayWidgets/
├── HaloWidgetBundle.swift
├── Widgets/ (TodayAgendaWidget.swift, ... 8 files)
├── LiveActivity/ (HaloLiveActivity.swift)
├── Intents/ (ToggleRitualIntent, StartFocusIntent, PauseFocusIntent, EndFocusIntent, PresetEntity, CountdownEntity, RitualEntity)
HaloKit/
├── Sources/HaloCore/ (Models, Services, Theme, Fixtures)
└── Sources/HaloUI/ (Components, WidgetViews, Mocks)
```

Intents used by both the app and widgets (e.g. `ToggleRitualIntent`) live in `HaloCore` so both targets compile them.

### 16.3 Architecture pattern

- SwiftUI + `@Observable` view models per feature (`TodayModel`, `StudioModel`, ...), injected via `@Environment`.
- Services are protocols with live and preview/mock implementations:
  - `CalendarService` (EventKit): `authorizationStatus`, `requestAccess()`, `events(in: DateInterval, calendars:)`, `calendars()`, `changes: AsyncStream<Void>` (from `EKEventStoreChanged`).
  - `RitualStore` (SwiftData)
  - `PresetStore` (SwiftData)
  - `FocusService` (session state + Live Activity)
  - `LiveActivityService` (ActivityKit wrapper)
  - `NotificationScheduler` (rolling 64-window planner)
  - `EntitlementStore` (StoreKit 2)
  - `WidgetSnapshotWriter` (writes JSON snapshots to the App Group)
  - `ThemeStore` (themes registry + active app theme)
- No third-party dependencies in MVP.

### 16.4 Data model (SwiftData, stored in App Group container)

```swift
@Model final class Ritual {
    var id: UUID = UUID()
    var name: String = ""
    var glyph: String = "sparkles"
    var kindRaw: String = "check"        // check | count
    var target: Int = 1
    var scheduleRaw: String = "daily"    // daily | weekdays | custom
    var customWeekdays: [Int] = []       // 1...7 (Calendar weekday)
    var timeOfDayRaw: String = "anytime"
    var reminderTime: DateComponents?    // hour/minute
    var sortIndex: Int = 0
    var createdAt: Date = Date()
    var archived: Bool = false
    @Relationship(deleteRule: .cascade) var logs: [RitualLog]? = []
}

@Model final class RitualLog {
    var id: UUID = UUID()
    var day: Date = Date()               // startOfDay in user's calendar
    var count: Int = 0
    var ritual: Ritual?
}

@Model final class WidgetPreset {
    var id: UUID = UUID()
    var name: String = ""
    var themeIDRaw: String = "pearlHalo"
    var isActive: Bool = false
    var slotsData: Data = Data()         // JSON [PresetSlot]
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
}

struct PresetSlot: Codable, Hashable {
    var position: SlotPosition           // inline | row0...row3 | home(size)
    var family: WidgetFamilyCode         // inline|circular|rectangular|small|medium|large
    var type: WidgetTypeCode             // agenda|month|week|mini|habit|focus|countdown|ritual
    var options: SlotOptions             // calendars, ritualIDs, countdownID, includeAllDay
}

@Model final class Countdown {
    var id: UUID = UUID()
    var title: String = ""
    var targetDate: Date = Date()
    var glyph: String = "calendar"
}

@Model final class FocusSession {
    var id: UUID = UUID()
    var label: String?
    var start: Date = Date()
    var plannedEnd: Date = Date()
    var actualEnd: Date?
    var completed: Bool = false
}
```

Settings live in `UserDefaults(suiteName: "group.co.haloday.shared")` via a typed `AppSettings` wrapper.

### 16.5 Widget data flow

```
App (EventKit) ──► WidgetSnapshotWriter ──► AppGroup/snapshot.json
                                               { generatedAt, days: [ { date, events:[{id,title,start,end,allDay,calendarColorHex,calendarTitle,location}] } ] (today + 6 days),
                                                 monthEventDays: [Int] }
App (SwiftData) ─────────────────────────────► AppGroup/HaloDay.store  (rituals, presets, countdowns)
App (StoreKit) ──────────────────────────────► AppGroup/entitlement.json
                                                      │
Widget TimelineProvider ◄─────────────────────────────┘
  1. read snapshot (if older than 6h AND calendar authorized → query EventKit directly as fallback)
  2. read SwiftData (rituals/presets) via a shared ModelContainer(url: appGroup)
  3. resolve PresetEntity → theme + slot options
  4. build entries (9.5)
```

Writing the snapshot: on launch, on foreground, on `EKEventStoreChanged`, in `BGAppRefreshTask` (schedule every ~4h, best-effort), and after settings changes.

### 16.6 Fixtures (for previews, Studio scenarios, snapshots)

`HaloCore/Fixtures/`:
- **Morning:** 09:00 Standup (Work), 10:30 Design review (Work, Studio B), 13:00 Lunch with Mai (Personal), 16:00 Pilates (Health), 19:30 Dinner at Noma (Personal). Rituals: Water 3/8, Journal ✓, Read ✗, Skincare ✗, Walk ✓.
- **Busy day:** 9 events, two overlapping.
- **Empty day:** none.
- **Focus running:** "Deep work", 50 min, 18 min elapsed.

All SwiftUI previews use fixtures. Every screen must have `#Preview`s for: light theme, dark theme, AX3 Dynamic Type, empty state.

### 16.7 Notifications planner

Sources: event reminders (per setting + per-event overrides), ritual reminders (repeating `UNCalendarNotificationTrigger`; these count toward the 64 limit), morning brief, trial reminder, focus end. Planner priority when > 64: focus end > trial > rituals > morning brief > events (soonest first). Re-plan on launch, foreground, `EKEventStoreChanged`, and in BG refresh.

---

## 17. Build Order & Acceptance Criteria

### 17.1 Build order (milestones)

1. **Foundation:** project, targets, App Group, HaloKit package, theme tokens (all 8 palettes), typography, spacing, components (7.11), fixtures. *Done when:* a `DesignSystemGallery` debug screen renders all components in all themes.
2. **Data:** CalendarService, SwiftData models, AppSettings, snapshot writer.
3. **Today + Calendar** with real EventKit data and all empty states.
4. **Widgets:** TodayAgenda + MonthProgress (all families, all rendering modes), then the remaining 6 kinds, intents, and locked states.
5. **Studio + Themes + Presets**, including vibrant simulation and the how-to sheet.
6. **Rituals** (+ interactive widget).
7. **Focus + Live Activities + Dynamic Island.**
8. **StoreKit + Paywall + gating everywhere.**
9. **Onboarding** (built last so it uses real components), notifications planner, Settings.
10. **Polish:** accessibility pass, motion, haptics, App Store screenshots.

### 17.2 Acceptance criteria (MVP)

**Platform & data**
- [ ] With calendar access, Today shows today's events from all enabled calendars within 300ms of launch on iPhone 13 or newer.
- [ ] Changing an event in Apple Calendar updates Today (foreground) immediately and the widgets within one timeline reload.
- [ ] With calendar access denied, no screen crashes or looks broken. Every surface shows its designed empty state.
- [ ] Widgets show sample data in the widget gallery before onboarding is done.

**Widgets**
- [ ] Every kind/family in 9.3 renders correctly in `.fullColor`, `.accented`, and `.vibrant` (verified with Xcode previews using `.widgetRenderingMode`).
- [ ] A Lock Screen rectangular agenda widget shows "NOW" during an event and the next event after it ends, with no app launch.
- [ ] The ritual toggle from a medium Home Screen widget updates within 1s and is reflected in the app.
- [ ] Free users installing a premium widget see the locked state, and tapping opens the paywall.
- [ ] A widget configured with "Active preset" changes theme when the active preset changes.

**Live Activities**
- [ ] Starting a focus session (Premium) shows a Lock Screen banner, Dynamic Island compact/minimal/expanded, with a live countdown and working Pause/End buttons.
- [ ] On devices without the Island, the Lock Screen banner works.
- [ ] Only one Halo Live Activity exists at a time.

**Design**
- [ ] No hex literal outside `ThemePalettes.swift` (enforce with a unit test that greps sources, or a SwiftLint custom rule).
- [ ] Unit test: `accentInk` vs `bg` & `surface` ≥ 4.5:1 and `ink` vs `bg` ≥ 7:1 for all palettes.
- [ ] All app screens are usable at AX3 Dynamic Type (layouts switch to vertical stacks via `ViewThatFits` or `dynamicTypeSize` checks).
- [ ] Reduce Transparency replaces glass. Reduce Motion removes staggered offsets and halo breathing.

**Monetization**
- [ ] Purchase, restore, and trial-eligibility flows work with `HaloDay.storekit` in the simulator.
- [ ] Prices are rendered from StoreKit only.
- [ ] The paywall close button is visible immediately. No auto-presented paywall outside the onboarding soft gate.
- [ ] Free features listed in 12.2 never require Premium.

**Privacy**
- [ ] No network requests are made by the app at all in MVP, except StoreKit (verify with the Network Instruments template or a `URLProtocol` assertion in debug).

---

*End of spec. Questions that must be answered by a human before release (not blocking MVP code): final App Store pricing per region, final wallpaper art and app icon, and legal URLs for Terms/Privacy. Bundle identifier prefix: `co.haloday`.*
