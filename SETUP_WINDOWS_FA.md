# راه‌اندازی پروژه روی ویندوز

## نرم‌افزارهای لازم

فقط این سه مورد را نصب کنید:

1. **Git for Windows**
2. **Flutter SDK Stable**
3. **Android Studio**

داخل Android Studio از مسیر `Settings > Plugins` افزونه **Flutter** را نصب کنید. افزونه Dart همراه آن نصب می‌شود.

## آماده‌سازی Flutter

Flutter را در مسیر ساده‌ای مانند زیر استخراج کنید:

```text
C:\dev\flutter
```

سپس مسیر زیر را به `Path` ویندوز اضافه کنید:

```text
C:\dev\flutter\bin
```

در PowerShell اجرا کنید:

```powershell
flutter doctor
flutter doctor --android-licenses
```

برای همه مجوزها حرف `y` را وارد کنید.

## ساخت پروژه

پوشه پروژه را در یک مسیر کوتاه و انگلیسی قرار دهید، مثلاً:

```text
C:\dev\masir_balini
```

سپس فایل زیر را دوبار کلیک کنید:

```text
01_PREPARE_PROJECT.bat
```

این فایل به‌صورت خودکار:

- پوشه Android را ایجاد می‌کند؛
- وابستگی‌ها را دریافت می‌کند؛
- آیکون برنامه را می‌سازد؛
- کد را تحلیل می‌کند؛
- تست‌ها را اجرا می‌کند.

## اجرای روی گوشی

در گوشی Android:

1. وارد `Settings > About phone` شوید.
2. چند بار روی `Build number` بزنید.
3. وارد `Developer options` شوید.
4. `USB debugging` را روشن کنید.
5. گوشی را با کابل داده وصل کنید.
6. پیام اجازه اتصال روی گوشی را تأیید کنید.

حالا اجرا کنید:

```text
02_RUN_ON_PHONE.bat
```

## ساخت APK

پس از اینکه برنامه روی گوشی درست اجرا شد، فایل زیر را اجرا کنید:

```text
03_BUILD_APK.bat
```

خروجی در این مسیر خواهد بود:

```text
build\app\outputs\flutter-apk\app-release.apk
```

## در صورت خطا

ابتدا اجرا کنید:

```text
04_CLEAN_AND_RETRY.bat
```

اگر باز هم خطا باقی ماند، متن کامل خطا را کپی کنید. فقط آخرین خط خطا کافی نیست.
