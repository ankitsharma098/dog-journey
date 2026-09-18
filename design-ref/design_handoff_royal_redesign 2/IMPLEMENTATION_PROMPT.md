# Starting prompt for Claude Code

Paste this into Claude Code from the root of `ankitsharma098/dog-journey`, with this handoff folder available (or its contents dropped into the repo).

---

I'm implementing a full UI/UX redesign of this Flutter app. The design reference is in `design_handoff_royal_redesign/`:

- `README.md` — the complete spec: tokens, every screen, interactions, state.
- `Dog Journey Royal Redesign.html` — an interactive HTML prototype. Open it in a browser; the chips under the first phone jump between all 16 screens. Treat it as the source of truth for look and behaviour.

**These HTML files are design references, not code to port.** Rebuild the designs in this codebase's own idioms: Flutter + Material 3, BLoC/Cubit, `go_router`, `GlassScaffold`/`GlassCard`/`GlassContainer`, `google_fonts`.

Read `design_handoff_royal_redesign/README.md` in full before writing code. Then start with the foundation, and stop for review after step 2:

1. **Tokens** — rewrite `lib/core/theme/app_colors.dart` and `lib/core/theme/app_theme.dart` with the dark and light palettes in the README. Dark is the primary theme. Standardise on Inter (drop Sora). Card radius 16–22, outlined primary buttons, no flat accent fills.
2. **Navigation** — rework `lib/core/routing/home_shell.dart` and `lib/core/widgets/nav/pill_bottom_nav.dart` from five tabs to **four tabs + a centre FAB**: Home · Passport · ＋ · Nutrition · Chat. The FAB opens an action sheet (Scan a breed / Add a health record / Log food / Add a memory). Breed Scanner stops being a tab and becomes a pushed route.

Then, one PR-sized change at a time:

3. **Entry flow** — restyle `lib/core/routing/splash_screen.dart`, `lib/features/auth/presentation/screens/sign_in_screen.dart` and `sign_up_screen.dart`, and `lib/features/pets/presentation/screens/add_pet_screen.dart` (sections 0a–0d of the README). Keep the existing field sets, `Validators` messages and Cubit wiring exactly as they are — this is a visual pass plus the photo-drop and segmented-sex treatments. Do **not** add social sign-in.
4. **Home dashboard** — a new screen and route; it becomes tab 1. See "Home dashboard" in the README. Reads from `PetsBloc`, the reminders table (`db-design/06_billing_reminders.sql`) and `NutritionCubit`.
5. **Health Passport** — restyle `lib/features/health_passport/`: segmented control, timeline rail, vaccine status chips, weight chart, med-course progress. Keep the existing repositories.
6. **Care calendar** — a new screen grouping reminders into Overdue / This month / Later, with complete-in-place.
7. **Vet Chat** — restyle `lib/features/vet_chat/`. Critical: keep the persistent composer, add the suggestion-chip row above it, add the emergency block driven by `assets/data/triage_rules.json`, and keep the disclaimer readable (`rgba(233,233,237,0.72)`, not dimmer).
8. **Nutrition** — restyle `lib/features/nutrition/`: conic ring (a `CustomPainter` beats `fl_chart` here), champagne treat-budget bar, quick-add chips for the pet's usuals.
9. **Breed Scanner + result** — viewfinder framing, and the post-scan locked "Breed health watchlist" teaser that opens the paywall.
10. **Memory Timeline** — the "Story" masthead, month grouping, full-bleed photo cards.
11. **Paywall + Settings** — both paywall surfaces (bottom sheet for soft teasers, full-screen for hard gates), RevenueCat wiring, and the Settings screen including delete-account with its 30-day grace note. Restore purchases and Terms/Privacy links are mandatory on both paywall surfaces.

Constraints:
- Exact hex values, type sizes and radii from the README — don't approximate.
- Phosphor icons (`phosphor_flutter`), fill variant for active/emphasis, regular otherwise.
- Every tap target ≥ 44px. Body text ≥ 4.5:1 contrast.
- Support both light and dark themes; the README lists both palettes.
- Don't change Supabase schema, repositories or Cubit APIs unless a screen genuinely needs new data — say so first.

Start with step 1 and show me the diff.
