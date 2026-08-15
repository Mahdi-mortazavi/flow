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
- Phase 2 (done, v0.2.0): habits with anchor cue + daily actionable
  notifications («انجام شد ✓» action), bad-habit friction sheet (10s pause +
  cost + one-tap replacement), recovery messaging, guilt-free fun block.
- Phase 3 (done, v0.2.0): stats "mirror" screen (win rate, prediction-optimism
  gap, recovery rate, 7-day deep-work chart, interrupt patterns, last nights),
  weekly zero-based review, energy check-ins + golden hour.
- Reliability sprint (done, v0.4.1): smart morning/evening/weekly OS
  reminders (skip when planned/closed; times set in onboarding + settings
  sheet), midnight rollover watcher, launcher icon + monochrome notif icon
  (`ic_stat_dot`), JSON backup/restore (share_plus/file_picker), undo for
  deletes, deferred review deletions, exact-alarm request + hint, battery
  guide (android_intent_plus), a11y (44px targets, ink3=38%, Semantics,
  textScale clamp 1.3), human ErrorCard.
- Product-gap sprint (done, v0.5.0): long-press task edit/delete
  (renameTask/removeTaskFromDay — boulder deletion promotes next), one-tap
  interrupt tag chips (InterruptTag enum) + ranked 30-day pattern in mirror,
  fun soft-lock until boulder falls (temptation bundling), optimism hint
  gated to ≥5 closed nights (StatsData.optimismReliable), quick_actions app
  shortcut «ثبت فکر». DB v3 adds focus_sessions.interrupt_tag + day/tag
  indexes.
- Distribution sprint (done, v0.5.2): fixed "problem parsing the package" —
  releases now ship a universal APK alongside the per-ABI splits, are signed
  with a real release key, and every artifact is verified in CI before it can
  be published. README has a real-device screenshot gallery.
- Phase 4: home widget, live activity, identity/values layer, DND.

## Known quirks
- RELEASE-ONLY crash class (fixed v0.5.1): resources referenced only from a
  Dart runtime string (e.g. the `ic_stat_dot` notification icon) get dropped
  by the release resource shrinker → `flutter_local_notifications` throws
  `invalid_icon`. Because `main()` awaited `Notifications.init()` before
  `runApp()`, that threw before first frame → blank-screen on launch (seen on
  Galaxy A30s / Mali / Android 11; debug builds are unaffected since they
  don't shrink). Fixes: (1) `ic_stat_dot` is now PNG in every drawable-*dpi +
  `res/raw/keep.xml` + `isShrinkResources/isMinifyEnabled = false` in the
  release buildType; (2) notification init is fully guarded and never blocks
  `runApp()`. Rule: never do failable async work before `runApp()`; verify
  release (not just debug) on a Mali device. `aapt2 dump resources <apk>` to
  check a resource survived the release build.
- The v0.4.0 GitHub release/tag was cut from a stale commit (commit failed
  because the -m here-string contained double quotes → tag landed on the
  old HEAD). v0.4.1 is the correct release. Write commit messages to a temp
  file and use `git commit -F` when they contain quotes.
- Test files each set `AppDatabase.fileName` in setUpAll — parallel test
  isolates must not share one sqlite file.

## Releases
- Pushing a `v*` tag publishes a GitHub Release with FOUR APKs + a `.sha256`
  each: `universal` (all ABIs — the one to hand users) plus `arm64-v8a`,
  `armeabi-v7a`, `x86_64`. Release body comes dynamically from the git commit
  message / tag annotation. Version lives in pubspec (`version: x.y.z+n`).
- Release signing (v0.5.2+) uses a real keystore, NOT the debug key. The
  keystore lives OUTSIDE the repo at `E:\flow-signing\` (with backups +
  KEYSTORE-README.txt); CI reads it from the `ANDROID_KEYSTORE_BASE64` /
  `_PASSWORD` / `ANDROID_KEY_ALIAS` / `ANDROID_KEY_PASSWORD` secrets. Losing
  that keystore means no user can ever update in place again.
- The workflow verifies every APK before publishing and aborts on failure:
  zip integrity, `aapt dump badging` (minSdk 24), universal really carries all
  three ABIs, `apksigner verify` with v2+v3, and it REFUSES to publish
  anything signed with the Android debug certificate.
- SDK levels are pinned explicitly in `app/build.gradle.kts` (minSdk 24 /
  target 36 / compile 36), not inherited from `flutter.*`, so an SDK bump
  can't silently change which devices can install.

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
