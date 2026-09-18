# Handoff: PawJourney — Royal Redesign (all modules)

## Overview

A full visual and UX redesign of the PawJourney dog-care app (`ankitsharma098/dog-journey`, branch `master`, Flutter + Supabase). It covers all six PRD modules — Breed Scanner, Health Passport + Reminders, AI Vet Chat, Nutrition, Memory Timeline, and Billing/Paywall/Settings — plus two screens that do not exist upstream: a **Home dashboard** and a **Care calendar**.

Two structural changes from the current app:

1. **Navigation** moves from five equal tabs to **four tabs + a centre FAB**: `Home · Passport · ＋ · Nutrition · Chat`. Breed Scanner, Add Record, Log Food and Add Memory all live behind the FAB action sheet — the scanner is an action, not a destination.
2. **A Home dashboard is the landing tab.** The app currently opens on an empty passport. Home leads with the pet's identity card, then "Needs you this week", then the vet-chat companion card, then the story strip.

The emotional targets, in order: **companionship** (the vet chat is awake when you are) and **nostalgia** (the story of a life). "Royal" is expressed as a deep ink ground, a champagne hairline reserved for the passport/crest/Pro, engraved uppercase tracking, and generous margins — *not* gold everywhere.

## About the Design Files

The files in this bundle are **design references created in HTML**. They are prototypes that show intended look and behaviour — they are **not production code to copy**.

The task is to **recreate these designs in the existing Flutter codebase**, using its established patterns: `GlassScaffold` / `GlassCard` / `GlassContainer`, `AppColors` / `AppTheme`, BLoC/Cubit state, `go_router`, `GoogleFonts`. Update `lib/core/theme/app_colors.dart` and `app_theme.dart` with the tokens below rather than hard-coding colours in widgets.

## Fidelity

**High-fidelity.** Colours, type, spacing, radii and interaction states are final and exact. Recreate pixel-for-pixel using Flutter widgets. Imagery is the one exception: every photo is a striped placeholder — real photography is still needed.

Phone canvas is **390 × 844** (iPhone 14/15 logical size). All values below are logical pixels at that width.

---

## Design Tokens

### Dark theme (primary)

| Role | Value |
| --- | --- |
| Canvas / scaffold | `#161826` |
| Card / surface | `#232532` |
| Sheet + tab-track surface | `#1D1F2C` |
| Text primary | `#E9E9ED` |
| Text secondary | `rgba(233,233,237,0.62)` |
| Text tertiary / meta | `rgba(233,233,237,0.45)` |
| Hairline / card border | `rgba(233,233,237,0.08)` |
| Divider (stronger) | `rgba(233,233,237,0.16)` |
| Accent (primary) | `#9184D9` |
| Accent light (icons, links, active nav) | `#B5ABFC` |
| Accent lightest (on tint) | `#D2CEFD` |
| Accent deep (fills, gradients, user bubble) | `#5D5294` |
| Accent tint (fills/hover) | `rgba(145,132,217,0.14 → 0.25)` |
| Champagne (gold) | `#D8BD86` |
| Champagne tints | `rgba(216,189,134,0.06 → 0.22)` |
| Success | `#5FC79A` |
| Warning / due soon | `#E0A458` |
| Danger / overdue | `#E0736B` |
| Emergency text on danger tint | `#F5A49D` (contrast-corrected) |

### Light theme

| Role | Value |
| --- | --- |
| Canvas | `#F3F2F7` |
| Card | `#FFFFFF` |
| Text primary | `#1B1A24` |
| Text secondary | `#6A6878` |
| Text tertiary | `#8B8998` |
| Hairline | `rgba(27,26,36,0.08)` |
| Accent | `#5D5294` (deeper than dark theme, for contrast on white) |
| Champagne | `#8A6F34` |
| Warning | `#A4661A` |
| Danger | `#B54A42` |
| Card shadow | `0 6px 18px rgba(27,26,36,0.06)` |
| Nav bar shadow | `0 8px 24px rgba(27,26,36,0.10)` |

### Typography — Inter throughout

| Use | Size / weight / tracking |
| --- | --- |
| Screen title (Home H1, Story, Settings) | 24px / 700 / −0.02em |
| Pet name on passport card | 24px / 700 / −0.02em |
| Screen title (Passport, Nutrition) | 21px / 700 / −0.02em |
| Sheet title | 20px / 700 / −0.02em |
| Onboarding H1 | 30px / 600 / −0.02em, line-height 1.18 |
| Section heading | 15px / 600 |
| List row title | 13.5px / 600 |
| Body | 13px / 400 / line-height 1.6 |
| Secondary line | 11.5px / 400 |
| Meta / caption | 11px / 400 |
| **Engraved label** (kickers: "HEALTH PASSPORT", "TODAY") | 9px / 600 / **0.30em** / uppercase / champagne |
| Chip / status pill | 10px / 600 / 0.08–0.12em / uppercase |
| Mono (passport number, dates in timeline) | 10px ui-monospace / 500 / 0.12em |

Minimum tap target is 44px; nav items are 64px tall, the FAB is 62px.

### Radii

Pet/hero card 22 · content card 16–18 · stat tile 14 · input 14–16 · chip 11–13 · segmented track 14, thumb 11 · bottom sheet top 26 · nav pill 26 · FAB 31 (circle) · device frame 46.

### Spacing

Screen horizontal padding 20 (22 on the alternate home). Card padding 14–22. Gap between list rows 8. Gap between sections 24–26. Scroll bottom padding 150 (230 on Vet Chat, to clear the composer).

### Shadows / elevation

Dark: elevation is an edge plus ambient darkness — `1px` hairline border, plus `0 10px 26px rgba(93,82,148,0.5)` on the FAB only. Nav bar uses `backdrop-filter: blur(14px)` over `rgba(35,37,50,0.94)`.

---

## Screens

### 0a. Splash
**Purpose:** the moment between app start and the first Supabase Auth event (`splash_screen.dart`; the router redirects the instant `AuthBloc` leaves `AuthInitial`). It is a hold, not a timed intro — no progress bar, no tagline, nothing that implies waiting.
**Layout:** centred on a radial gradient `radial-gradient(100% 50% at 50% 42%, #2B2741, #161826 70%)`: a 104px gold-outlined circle with a filled paw, the wordmark at 11px / 600 / **0.44em** tracking, and a 96px gold hairline that fades at both ends. That's all.

### 0b. Sign in
Matches `sign_in_screen.dart` exactly: **Email** and **Password** only, a right-aligned `Forgot password?` text button (opens the existing forgot-password sheet), a 54px outlined primary `Sign in`, and a centred footer `New here? Create an account`. There is deliberately **no** social sign-in — Supabase email/password is the only configured provider; adding Google/Apple is a scope decision, not a design one.
Brand row at the top (34px crest + engraved wordmark), H1 *"Welcome back"* 28/700, subtitle *"Your dog's whole story, in one place."* Password field has a trailing eye toggle. Validation copy from `core/utils/validators.dart`: "Enter your email." / "That email address doesn't look right." / "Enter your password." / "Use at least 6 characters."

### 0c. Sign up
Matches `sign_up_screen.dart`: back arrow, H1 *"Create your account"*, subtitle *"Breed, vaccines, weight, memories — all in one place, from day one."*, then **Email**, **Password** ("At least 6 characters"), **Confirm password** — no display-name field. Primary `Create account`, then the legal line *"By continuing you agree this app offers triage and record-keeping, not a substitute for veterinary care."* at 11px, left-aligned. Footer: `Already have an account? Sign in`. Confirm-password mismatch shows "Passwords don't match."

### 0d. Add dog
Matches `add_pet_screen.dart` — onboarding, not a settings form: **name is the only requirement**. Header shows `Step 2 of 2`. H1 *"Let's add your dog"*, subtitle *"Just a name to start — the rest can wait for a quieter evening."* Then: a 104px dashed-gold circular photo drop ("Add photo"), **Dog's name** field, **Sex** segmented (Male / Female / Not sure, default *Not sure*), **Birthdate** date field beside an optional dashed **Adopted** field, and a custom checkbox *"This is a guess, not the real date"* (only relevant once a birthdate exists). Primary `Add my dog`, then the reassurance line *"A passport number is issued the moment you save."* Empty name → "Give your dog a name." The button stays disabled through `submitting` **and** `success` so a second tap can't create a second pet.
This screen is also reachable from a breed-scan result (`initialBreedId` / `initialBreedMix`) — in that path it's a pushed route that pops on success rather than relying on the router redirect.

### 1. Onboarding
**Purpose:** first run, before any pet exists (matches the `addPet` gate in `app_router.dart`).
**Layout:** centred column on a radial gradient `radial-gradient(120% 60% at 50% 0%, #2B2741, #161826 62%)`. 96px gold-outlined circle with a filled paw glyph → 120px gold hairline → "PAWJOURNEY" engraved label → H1 *"Every dog deserves a record worth keeping."* → 14px body. Bottom: 3-dot progress (active dot is a 22×3 gold bar), primary outlined button 52px *"Create Sarthak's passport"*, ghost button *"I already have an account"*.

### 2. Home dashboard (new)
- **Brand row** — 30px gold-outlined paw circle, "PAWJOURNEY" engraved, spacer, `GO PRO` gold outline chip (26px), 30px gear icon button.
- **Passport hero card** — 22px radius, `linear-gradient(150deg, #2B2741, #232532 58%)`, 1px `rgba(216,189,134,0.22)` border. 70px circular photo with gold ring; name 24/700; breed + age 13px secondary. Then a **gold hairline that fades at both ends** (`linear-gradient(90deg, transparent, gold 18%, gold 82%, transparent)`), then a mono row: `PASSPORT · PJ-0042-SAR` / `ISSUED 2017`.
- **Three stat tiles** — equal grid, gap 8: Weight `31.2 kg`, Next shot `12 days` (warning colour), Today `123 /767`.
- **"Needs you this week"** — section heading + `All care` text button → Care calendar. Rows: 36px rounded icon tile on accent tint, title, subtitle, status chip right-aligned (`12 DAYS` warning / `OVERDUE` danger).
- **Companion card** — accent gradient `linear-gradient(135deg, rgba(145,132,217,.20), rgba(145,132,217,.06))`, 1px accent border. *"Still awake at 3am?" / "The vet chat is too. Ask anything about Sarthak."* → Vet Chat. This card is the emotional anchor; do not demote it.
- **"Nine years, so far"** — horizontal scroller of 112px memory thumbnails (square photo, title, date) → Story.

### 3. Health Passport
Header: engraved "HEALTH PASSPORT" + pet name, export icon button (PDF of the passport). **Segmented control** on a `#1D1F2C` track: Timeline / Vaccines / Meds / Weight — active segment is accent tint `rgba(145,132,217,0.22)` with `#E9E9ED` text, inactive `rgba(233,233,237,0.5)`.
- **Timeline** — left rail: 9px dot (champagne for vaccines, accent for everything else) with a 1px connecting line; right: card with title, mono date top-right, subtitle.
- **Vaccines** — syringe icon, name, "Given <date>", status chip: `DUE SOON` / `CURRENT` / `MISSING`.
- **Meds** — course card with a 6px accent progress bar ("6 of 14 doses given").
- **Weight** — 26px current weight + green delta, then a six-month bar chart (bars `linear-gradient(180deg,#9184D9,#5D5294)`, 6px top radius), then a plain-language reading of the trend.

### 4. Care calendar (new)
Back link → Home. H1 "Care calendar", one-line rationale. Three groups — **OVERDUE** (danger), **THIS MONTH** (warning), **LATER** (muted) — each an engraved label followed by a rule fading to transparent on the right. Rows carry a `Done` outlined button (28px) that completes the reminder in place.

### 5. Breed Scanner
Close (×) instead of back, title, `3 SCANS LEFT` gold chip (free tier). Viewfinder: 3:4 rounded 24px striped placeholder with an inset dashed gold guide rect and a horizontal accent scan line pulsing at 1.8s. Guidance copy below. Controls row: gallery (46px), 76px capture button (gold ring, accent tint fill), flash (46px).

### 6. Scan result
Photo (190px) + result card: engraved "MOST LIKELY", breed 23/700, confidence bar with accent gradient + `92%`, fading gold rule, then runner-up breeds as label/percent rows.
**Paywall teaser:** gold-tinted card, lock icon, "Breed health watchlist", two-line pitch, then **three blurred bars** (`filter: blur(3.5px); opacity:.5`) standing in for the locked content, then a gold outlined `Unlock with Pro` button → paywall sheet. Secondary outlined button: `Save breed to passport`.

### 7. AI Vet Chat
Header: 34px avatar tile, "Vet chat" + green `awake now`, quota chip right (`2 / 3 FREE`, or `PRO · UNLIMITED`).
- User bubble: `#5D5294`, radius `18 18 4 18`, right-aligned, max-width 80%.
- Assistant bubble: `#232532` + hairline, radius `18 18 18 4`, max-width 86%. Contains the answer (13.5/1.6), an optional **emergency block** (danger tint, 1px danger border, `#F5A49D` bold text) driven by `triage_rules.json`, and a disclaimer line at `rgba(233,233,237,0.72)` — this must stay above 4.5:1; do not dim it further.
- Typing indicator: three 6px accent dots blinking at 1s with 0.2s stagger.
- **Pinned composer**, sitting above the tab bar: a horizontally scrolling row of suggestion chips (always available, not just on the empty state), then a 50px input + 50px send button. Send is disabled and shows an hourglass while a reply is in flight; Enter submits.

### 8. Nutrition
Engraved "TODAY" + "Nutrition", search icon (food lookup).
- **Ring card**: 124px conic-gradient ring (`#9184D9` up to the consumed percentage, `rgba(233,233,237,.1)` after) with a 96px surface-coloured hole showing consumed kcal (24/700 accent) over "of 767 kcal". Right column: Remaining (success), Treat budget (champagne) `0 / 77 kcal`, and a 5px champagne progress bar. Ring turns danger when consumed ≥ target.
- **Quick add** — chips of the pet's usual foods with kcal; tapping one logs it instantly and updates the ring and treat bar. Treat items count against the 10% treat budget.
- **Logged today** — rows with bowl/cookie icon, name, kcal.

### 9. Memory Timeline ("Story")
Centred masthead: engraved "NINE YEARS AND COUNTING", H1 "Sarthak's story", a short centred gold hairline. Entries grouped by month (engraved month label) — 20px card with a 230px photo, title + share icon, date, and a caption in the owner's voice. Closes with a dashed gold card: "Print the year as a book" (Pro perk).

### 10. Paywall — bottom sheet (default)
Sheet from the bottom, `linear-gradient(170deg, #2B2741, #1D1F2C 45%)`, gold top border, 26px top radius, slide-up 0.22s. A slow diagonal **sheen** sweeps across it (3.6s loop) — the only animated flourish in the app. Content: 56px gold crest circle, engraved "PAWJOURNEY PRO", H2 *"Unlimited vet chat, and nothing left to memory."*, four check-marked perks, then three plan cards — Monthly `$9.99`, **Yearly `$59.99` / "save 50%"** (gold border + tint, the pre-selected one), Family `$14.99`. CTA `Start 7 days free` (54px, gold border, gold→accent gradient tint). Footer: Restore purchases · Terms · Privacy — **all three are mandatory** for store review.

### 11. Paywall — full-screen alternate
Same content as an investiture page: 84px crest, long gold hairline, H1 *"Nine years of Sarthak deserve better than a shoebox of receipts."*, four icon+text benefit rows, a single price block (`7 days free, then $59.99 a year` / `$4.99/mo billed yearly · or $9.99 monthly · family $14.99`), 56px CTA. Use this one for the hard gates (quota exhausted, multi-pet, cloud upload); use the sheet for soft teasers (post-scan, nutrition entry).

### 12. Settings
Pro status card (gold tint, crown, `Manage`), then grouped rows in 18px cards with 1px internal dividers:
- **Preferences** — Units segmented `lb / °F` ↔ `kg / °C` (imperial default), Time zone, Care reminders toggle (44×26 pill, `#5D5294` when on) with the subtitle "Two nudges: a week out, then the day of".
- **Account** — Restore purchases, Terms & privacy, **Delete account** in danger colour with a `30-day grace` note (soft-delete → `pg_cron` purge, per `0007_delete_account.sql`).

### 13. Home alternate (`1b` in the prototype)
A calmer, companion-first home: pet switcher in the header, the date, then a large sentence-as-status H1 — *"Sarthak is **doing well**. One thing needs you today."* — a single action card for the one thing due (Book a slot / Snooze), the vet-chat card phrased as the owner's own question, and two small tiles (kcal, memories). Pick this if you want the app to feel like a companion rather than a dashboard; pick the main home if information density matters more.

---

## Interactions & Behaviour

- **Tabs** switch instantly with an `IndexedStack`; no transition. Active nav item is `#B5ABFC` with a **filled** Phosphor glyph; inactive is `rgba(233,233,237,0.45)` with the outline glyph.
- **FAB** opens the action sheet: Scan a breed → scanner; Add a health record → record sheet; Log food → Nutrition; Add a memory → Story.
- **Sheets** animate `translateY(100%) → 0` over 0.22s ease-out, over a `rgba(10,10,17,0.62)` scrim. Tapping the scrim dismisses. Grabber is 38×4, `rgba(233,233,237,0.2)`.
- **Screen enter** animation: 6px rise + fade, 0.25s ease.
- **Add Record sheet** — type chips (Vaccine / Vet visit / Medication / Weight / Allergy / Preventive) change the first field's label and hint (e.g. Weight → "31.2 kg"). Date defaults to today; **Next due** is a dashed gold field pre-filled `+ 1 year`. Footnote: "A reminder is set automatically when a next-due date exists." Saving returns to the passport timeline.
- **Vet chat** — send appends the user bubble, shows the typing indicator for ~1.1s, then the reply. Chocolate/blood/seizure/not-breathing keywords render the emergency block; wire this to `assets/data/triage_rules.json` rather than client-side regex in production.
- **Nutrition quick-add** — optimistic: ring, remaining, treat bar and log all update on tap.
- **Hover/pressed** (for web/desktop builds): borders lift to `#9184D9`, tinted fills go one accent step deeper. Focus ring: 2px `#9184D9`, 2px offset.

## State

Per screen, on top of the existing Cubits: `activeTab`, `passportTab`, `activeSheet` (null | actions | record | paywall), `recordType`, `chatMessages` + `isTyping` + `draft`, `consumedKcal` / `treatKcal` / `todayLog`, `units`, `remindersEnabled`, `tier` (free | pro — gates the quota chip, scan counter and locked report).

## Assets

- **Icons:** [Phosphor](https://phosphoricons.com) — regular for inactive, fill for active/emphasis. Names used: `paw-print`, `house`, `identification-card`, `fork-knife`, `chat-teardrop-dots`, `plus`, `gear-six`, `crown-simple`, `syringe`, `scales`, `first-aid-kit`, `camera`, `images`, `bowl-food`, `cookie`, `export`, `lock-simple`, `check-circle`, `paper-plane-tilt`, `hourglass-medium`, `bell-ringing`, `calendar-blank`, `magnifying-glass`, `caret-right`, `arrow-right`, `arrow-left`, `x`, `bug`, `tooth`, `infinity`, `dog`, `cloud-check`, `heartbeat`, `lightning`, `warning`. Use the `phosphor_flutter` package.
- **Font:** Inter (400/500/600/700) via `google_fonts`. The current app mixes Sora for headings — the redesign standardises on Inter.
- **Photography:** all placeholders. Needed: pet avatar, memory photos, scan photo.

## Files in this bundle

- `Dog Journey Royal Redesign.html` — the standalone, offline, **interactive** prototype. Open it in a browser; the chips under the first phone jump between all 16 screens. Start here.
- `Dog Journey Royal Redesign.dc.html` — the editable source of the same prototype.
- `IMPLEMENTATION_PROMPT.md` — a ready-to-paste starting prompt for Claude Code.

## Design system

Visual tokens derive from the **Nocturne** design system (dark ground `#161826`, surface `#232532`, accent `#9184D9`, Inter, Phosphor icons, outlined primary buttons, rules that fade at their ends). The champagne `#D8BD86` is an addition for this product, used only on the passport, the crest and Pro surfaces. Do not flood the accent or the gold across large areas — both work as lines, marks and tints.
