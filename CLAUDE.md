# تک‌نقطه (taknoghte)

Flutter app (Android/iOS, RTL Persian) for focus/energy/time management.
Design language: "liquid glass ember" — near-black bg `#060608`, monochrome
glass cards, exactly ONE warm color (`#EFA55C` ember) reserved for the
boulder (تخته‌سنگ) and primary CTAs. Font: Vazirmatn (bundled, weights 200–800).

## Product model (Phase 1 — done)
- **Morning wizard**: pick ≤3 tasks from backlog, star one as the *boulder*,
  set a success prediction % (metacognitive calibration, checked at night).
- **Boulder-first**: other tasks are soft-locked until the boulder is done
  (escape hatch via confirm sheet).
- **Focus timer**: wall-clock based (`endAt` timestamp in shared_preferences),
  survives process death; end alarm scheduled on the OS
  (flutter_local_notifications, exact-with-fallback). Time-up sheet:
  done / +10min / not-yet. Early end asks for an interrupt note (stored).
- **Evening review**: final check, 3-level why-chain if boulder failed
  (system cause, no blame), one-line note; closing removes done tasks from
  backlog.
- **Brain vault**: instant thought dump (idea/worry/side-task), search,
  promote to today/backlog. Also reachable *inside* the focus screen.

## Roadmap
- Phase 2: habits (anchor cue + actionable notifications), bad-habit friction
  + replacement, recovery messaging, guilt-free fun block.
- Phase 3: stats "mirror" (win rate, prediction-optimism gap, recovery rate),
  focus-session archive, interrupt patterns, weekly zero-based review,
  energy check-ins.
- Phase 4: home widget, live activity, identity/values layer, DND, export.

## Architecture
- `lib/core/` — `theme.dart` (class `Tone`: design tokens; NOT `Ink` — clashes
  with Material), `fa.dart` (Persian digits, Jalali date, dayKey helpers).
- `lib/data/` — `database.dart` (sqflite, singleton), `models.dart`,
  `repo.dart` (all SQL). Plain sqflite, NO drift/codegen (drift_dev conflicts
  with riverpod 3 on Dart 3.9).
- `lib/state/` — Riverpod 3 (`Notifier`/`AsyncNotifier`): `providers.dart`
  (todayProvider, thoughtsProvider, dayKeyProvider), `focus_controller.dart`.
- `lib/services/notifications.dart` — v20 API uses NAMED params
  (`zonedSchedule(id:, scheduledDate:, notificationDetails:, ...)`).
- `lib/ui/` — `widgets/glass.dart` (GlassCard, Pill, sheets, toast, confirm),
  one folder per feature (today, wizard, focus, evening, vault).

## Gotchas
- NEVER bulk-edit lib/*.dart with PowerShell `Get-Content` — it mangles UTF-8
  Persian text (no BOM → ANSI). Use the Edit/Write tools.
- `BoxDecoration` with non-uniform `Border` + `borderRadius` throws at paint.
- Android: desugaring enabled in `app/build.gradle.kts` (required by
  flutter_local_notifications); notification receivers declared in manifest.
- Day key = local Gregorian `yyyy-MM-dd` (display is Jalali via shamsi_date).

## Commands
- `flutter analyze` / `flutter build apk --debug` / `flutter run`
