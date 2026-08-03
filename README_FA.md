# مسیر بالینی

اپلیکیشن فارسی آفلاین برای اجرای برنامه جامع کارشناسی ارشد روان‌شناسی بالینی.

## شروع سریع

در ویندوز ابتدا فایل `START_HERE_FA.txt` را بخوانید و سپس این فایل‌ها را به‌ترتیب اجرا کنید:

1. `01_PREPARE_PROJECT.bat`
2. `02_RUN_ON_PHONE.bat`
3. `03_BUILD_APK.bat`

## معماری

- Flutter / Dart
- SQLite با `sqflite`
- رابط کاملاً فارسی و RTL
- نمودار با `fl_chart`
- ساخت فایل Excel با پکیج `excel`
- فایل‌گیری با `file_picker`
- تاریخ شمسی با `shamsi_date`

## داده‌ها

داده اولیه از این فایل‌ها تأمین می‌شود:

```text
assets/seed/clinical_psychology_plan_1405_professional_final.xlsx
assets/seed/normalized_seed_v2.json
```

در اولین اجرا، داده‌ها وارد SQLite می‌شوند. پس از آن، SQLite منبع اصلی اطلاعات است.

## صفحات

- امروز
- برنامه
- مرورها
- گزارش‌ها
- تنظیمات

## خروجی‌ها

### Excel

از مسیر زیر داخل برنامه:

```text
تنظیمات > خروجی کامل اکسل
```

### پشتیبان کامل

از مسیر:

```text
تنظیمات > تهیه پشتیبان کامل
```

فایل پشتیبان با پسوند `.masirbackup` ساخته می‌شود.

## آزمون و ساخت

```bash
flutter pub get
dart run flutter_launcher_icons
flutter analyze
flutter test
flutter run
flutter build apk --release
```

## نکته مهم

این بسته شامل سورس آماده ساخت است، اما در محیط تولید این فایل Flutter و Android SDK در دسترس نبود؛ بنابراین APK داخل این بسته قرار ندارد. اولین کامپایل باید روی سیستم دارای Flutter و Android SDK انجام شود.
