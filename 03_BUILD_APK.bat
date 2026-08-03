@echo off
chcp 65001 >nul
cd /d "%~dp0"

echo ================================================
echo MASIR BALINI - BUILD RELEASE APK

echo ================================================

flutter pub get
if errorlevel 1 goto :failed
flutter analyze
if errorlevel 1 goto :failed
flutter test
if errorlevel 1 goto :failed
flutter build apk --release
if errorlevel 1 goto :failed

echo.
echo APK created successfully:
echo %CD%\build\app\outputs\flutter-apk\app-release.apk
start "" "%CD%\build\app\outputs\flutter-apk"
pause
exit /b 0

:failed
echo.
echo APK build failed. Copy the full error text.
pause
exit /b 1
