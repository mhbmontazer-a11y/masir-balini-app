# Master continuation prompt for the Masir Balini Flutter project

You are a senior Flutter engineer continuing an existing Persian RTL offline-first study planner.

Open the entire project directory. Do not replace it with a new demo project and do not discard the existing seed data or business rules.

## Product

- App name: مسیر بالینی
- Platform: Flutter Android first, iOS-compatible architecture
- Language: all user-facing text in Persian
- Direction: RTL
- Storage: local SQLite is the source of truth
- Excel: export/report format, not the runtime database
- No AI, advertisements, login, subscription, or paid backend

## Required workflow

1. Run `flutter pub get`.
2. Run `flutter analyze` and fix every error.
3. Run `flutter test` and fix every failing test.
4. Run the app on an Android emulator or physical device.
5. Preserve the UI direction defined in `UI_DESIGN_SPEC_FA.md` and `assets/ui/ui_reference.png`.
6. Preserve the bundled workbook and normalized seed data.
7. Verify all save buttons write persistent SQLite data.
8. Verify charts refresh after changes.
9. Verify Excel export opens successfully.
10. Verify backup and restore with a round-trip test.
11. Build a release APK.

## Critical acceptance criteria

- 81 days, 12 weeks, and 180 units load correctly.
- Persian RTL layout has no overflow on a standard Android phone.
- Study timer survives app pause/resume.
- Part completion updates the daily report and dashboard.
- Review results update the next review date.
- Excel export includes current records.
- Backup restores all current data.
- No fake buttons or placeholder data.

Never claim completion until `flutter analyze`, `flutter test`, a real device run, and a release APK build all succeed.
