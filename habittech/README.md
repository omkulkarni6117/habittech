# HabitTech

**Build Better Habits. Become Better Every Day.**

A local-first habit tracker for Android (and any other Flutter target) with a weekly workout planner. Light-blue, card-based design; works fully offline; no account needed.

> **Status: written without a compiler.** This project was authored in an environment that could not download Flutter or the Android SDK. The Dart code and tests have been reviewed by hand and with static checks (balanced syntax, resolved imports), but have **not been compiled or run**. Expect to fix a few small errors on first build. See [Known limitations](#known-limitations).

## Features

| Screen | What it does |
|---|---|
| **Dashboard** | Greeting, completion rate, completed today, current/best streak, week chart, month progress, most consistent habit, today's workout, daily motivation |
| **Today's Focus** | Checklist with All / Completed / Remaining filters, add / edit / archive / restore / delete (with confirmation), completion animation |
| **Monthly Habit Matrix** | Habits × days grid, tap a day to toggle, previous/next month, today highlight, legend, monthly %, frozen habit-name column, horizontal scroll |
| **Workout Planner** | Weekly plan Mon–Sun, exercise library, sets / reps / weight / rest or timed blocks, reorder, copy a day, rest days, tick exercises off, weekly summary |
| **Sleep Tracker** | Duration presets (5–9 h), bedtime / wake time (overnight-aware), quality, notes, weekly average, goal comparison, weekly chart, month history, edit past nights |
| **Progress Analytics** | Daily / weekly / monthly rates, streaks, consistency, per-habit performance, monthly trend, 12-week heatmap, sleep trend, total entries |
| **Notes & Reflections** | Dated notes, character count, saved state, edit / delete, search and date filter, draft kept when switching tabs |
| **Settings & Profile** | Name, light / dark / system theme, week start, daily goal, sleep goal, JSON export / import, reset or clear sample data, erase everything |

### Using the workout planner

1. Open **Workout** and pick a day in "Your week".
2. Tap **Add exercise**, choose from the library (search or filter by muscle group), set sets / reps / weight / rest, and add it. Use **New** to create your own exercise.
3. Drag the handle (or use the ⋮ menu → Move up / Move down) to reorder. Tap an exercise to edit its sets and reps.
4. Day menu (⋮): rename the session, mark a rest day, copy another day's plan, clear the day.
5. On the day itself, tick exercises off. A session counts as complete when every planned exercise is ticked. Future days can be planned but not ticked.
6. **Exercises** (top right) manages the library: add, edit, delete. Deleting an exercise removes it from every day of the plan.

## Build the APK

### Option A: on your computer

Install [Flutter](https://docs.flutter.dev/get-started/install) with Android Studio / the Android SDK and check `flutter doctor`. Then from this folder:

```bash
# macOS / Linux
bash tool/build_apk.sh

# Windows (PowerShell)
powershell -ExecutionPolicy Bypass -File tool\build_apk.ps1
```

This generates the `android/` project with your installed Flutter, runs the tests, builds a release APK and copies it to `dist/HabitTech.apk`. Copy that file to your phone and open it (Android will ask to allow installs from that source).

Run on a connected device or emulator instead:

```bash
flutter create --platforms=android --org com.habittech --project-name habittech .
rm -f test/widget_test.dart     # the generated counter test does not apply
flutter pub get
flutter run
```

### Option B: let GitHub build it

Push this folder to a GitHub repository. The workflow in `.github/workflows/build-apk.yml` builds the APK on every push (or run it manually from the Actions tab). Download `HabitTech-apk` from the run's artifacts. The analyze and test steps report problems but do not block the build.

### About the APK

It is a **release build signed with Flutter's debug key**, which is fine for installing on your own phone. To publish on Google Play you need your own upload keystore: <https://docs.flutter.dev/deployment/android>. The launcher icon is Flutter's default until you add your own (for example with the `flutter_launcher_icons` package).

## Project structure

```
lib/
  main.dart                 App entry, theme switching, lifecycle refresh
  app/                      AppShell (rail / bottom navigation), AppSection
  core/                     date_utils.dart, time_utils.dart (pure helpers)
  models/                   Habit, HabitCompletion, SleepEntry, Reflection,
                            UserSettings, workout models, AppData, json_helpers
  data/                     StorageRepository (+ local & in-memory),
                            backup (export/import), seed & starter exercises
  logic/                    habit_stats, sleep_stats, workout_logic (pure)
  state/app_state.dart      Single ChangeNotifier: all mutations live here
  theme/app_theme.dart      Design tokens, light & dark themes
  widgets/                  Reusable UI: cards, charts, dialogs, motion
  screens/                  The eight screens
test/                       Unit tests + widget smoke tests
tool/                       APK build scripts
```

Layers only depend downward: screens → state → logic/data → models/core. Calculations never touch widgets, and widgets never touch storage.

## Storage architecture

* **Single snapshot.** Everything is one immutable `AppData` value (habits, completions, sleep, reflections, exercises, workout plan, workout progress, settings). Each change builds a new snapshot, updates the UI immediately, and queues a write.
* **Repository interface.** `AppState` talks only to `StorageRepository` (`load / save / clear`). The shipped `LocalStorageRepository` stores one JSON string in `SharedPreferences` under `habittech.data.v1`. To add Supabase or another backend, implement the same interface (for example one row set per authenticated user, protected by row-level security, using only the anon key on the client) and pass it to `AppState`. No UI change is needed. **A cloud implementation is not included.**
* **Safe loading.** Saved data is validated strictly on read. If it is unreadable, the raw text is copied to `habittech.data.unreadable-backup`, sample data is loaded, and a dismissible warning is shown. Data is never silently discarded.
* **First run** loads sample data (7 habits, 45 days of history, 14 nights of sleep, notes, and a full weekly workout plan). It can be cleared or reset from the dashboard banner or Settings.
* **Backups.** Export produces pretty-printed JSON (copied to the clipboard); import validates *everything* (types, real calendar dates, `HH:mm` times, unique ids, no duplicate habit-and-day completions, completions pointing at real habits, workout plan pointing at real exercises) before replacing any data.

### Data models

| Model | Key fields |
|---|---|
| `Habit` | id, name, description, icon, category, schedule (daily / chosen weekdays), goalValue + goalUnit, reminderTime, startDate, createdAt, archivedAt |
| `HabitCompletion` | habitId, date (`yyyy-MM-dd`), completed, completedAt. Id is `habitId_date`, so duplicates cannot exist |
| `SleepEntry` | date (wake-up day), bedtime, wakeTime, durationMinutes, quality 1–5, notes. One per date |
| `Reflection` | id, date, content, createdAt, updatedAt |
| `UserSettings` | displayName, dailyHabitGoal, sleepGoalMinutes, theme, weekStartsOn |
| `Exercise` | id, name, muscleGroup, kind (sets & reps / timed), equipment, notes, defaults |
| `WorkoutPlan` | exactly 7 `WorkoutDay`s (title, isRest, ordered `PlannedExercise`s with sets, reps, weightKg, durationMin, restSec, notes) |
| `workoutProgress` | date → set of ticked planned-exercise ids |

Dates are **local calendar-day keys** (`yyyy-MM-dd`), never UTC instants, so a completion at 11:50 PM stays on that day in any time zone, and day arithmetic uses the date constructor so daylight-saving changes cannot shift a day.

## Formulas

Defined in `lib/logic/habit_stats.dart`.

* **Scheduled check-in**: a (habit, day) pair where the day is on/after the habit's start date, on/before its archive day, and on a scheduled weekday. Days after today are never counted, and a missing record is *not completed* (never assumed done).
* **Completion rate** (any range) = completed check-ins ÷ scheduled check-ins. Shown as "-" when nothing was scheduled.
* **Successful day**: at least one habit scheduled and `completed ≥ min(dailyGoal, scheduled)`.
* **Consistency** = successful days ÷ days that had scheduled habits. This is calendar-day consistency and intentionally differs from completion rate: finishing 5 of 7 habits every day with a goal of 5 is 71% completion but 100% consistency.
* **Streak**: consecutive successful days. Days with nothing scheduled are neutral. Today never *breaks* the current streak while in progress; it extends it once the daily goal is met.
* **Best streak**: the longest run anywhere in the history.
* **Most consistent habit**: best completion rate over the last 30 days with at least 3 scheduled check-ins.
* **Creating or archiving a habit never rewrites the past**: it only counts from its start date until its archive day.
* **Sleep duration** = wake − bedtime, adding 24 h when wake is earlier (23:00 → 07:00 = 8 h). The weekly average uses only nights that were logged.
* **Workout session** = complete when every planned exercise for that weekday is ticked on that date. Time is an estimate: strength sets ≈ 40 s work + rest; timed items use their duration.

## Tests

```bash
flutter test
```

| File | Covers |
|---|---|
| `date_time_test.dart` | Month lengths, leap years (incl. 1900 / 2000), date-key parsing, week starts, overnight sleep |
| `habit_stats_test.dart` | Daily / weekly / monthly rates, start dates, weekly schedules, archiving, current & best streaks, consistency vs completion |
| `app_state_test.dart` | Toggling, no duplicates, future dates, persistence after reload, corrupt storage, sleep, reflections, export / import |
| `backup_test.dart` | Import validation (bad JSON, versions, dates, times, duplicates, dangling references, ranges) |
| `workout_test.dart` | Planning, reordering, copying, library deletion, ticking, weekly summary, estimates |
| `widget_smoke_test.dart` | Every screen builds on a 320 px phone and a desktop window; tapping a check button persists |

## Deploying

* **Android**: build the APK (above), or `flutter build appbundle --release` for Google Play after setting up signing.
* **Other platforms**: `flutter create --platforms=ios,web,windows .` adds them. Web uses `localStorage` through `shared_preferences`; the 64-bit random-number seed in `seed_data.dart` assumes native integers, so sample-data values may differ slightly on web.

## Known limitations

* **Not compiled or run** by its author. Fix any compile errors the first build reports, and run `flutter test`; a failing test may be a test mistake rather than an app bug.
* **No device notifications.** A habit's reminder time is saved with the habit but nothing is scheduled. (This avoids requesting notification permission without a working feature.)
* **Backup is copy and paste** through the clipboard, not a file picker.
* **No cloud sync or accounts.** The repository interface is ready for it; an implementation is not included.
* Charts are drawn with Flutter's own widgets (no charting package), so they have no tap tooltips.
* Habit-icon choices are limited to 25 built-in Material icons.
* The matrix does not support backfilling future dates (by design).
* Visual design follows the described palette and layout. It was not compared against the original reference screenshots, which were not available to the author.
