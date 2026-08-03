@echo off
chcp 65001 >nul
cd /d "%~dp0"

echo ================================================
echo MASIR BALINI - PREPARE PROJECT
echo ================================================

where flutter >nul 2>nul
if errorlevel 1 (
  echo Flutter was not found. Install Flutter and add flutter\bin to PATH.
  pause
  exit /b 1
)

where git >nul 2>nul
if errorlevel 1 (
  echo Git was not found. Install Git for Windows first.
  pause
  exit /b 1
)

echo [1/6] Checking Flutter...
flutter doctor
if errorlevel 1 (
  echo Flutter doctor reported a problem. Fix Android toolchain issues first.
  pause
  exit /b 1
)

echo [2/6] Creating Android platform files...
copy /Y pubspec.yaml pubspec.masir.backup.yaml >nul
flutter create --platforms=android --org ir.masirbalini --project-name masir_balini .
if exist pubspec.masir.backup.yaml (
  copy /Y pubspec.masir.backup.yaml pubspec.yaml >nul
  del pubspec.masir.backup.yaml
)
if errorlevel 1 goto :failed

echo [3/6] Downloading Flutter packages...
flutter pub get
if errorlevel 1 goto :failed

echo [4/6] Creating launcher icons...
dart run flutter_launcher_icons
if errorlevel 1 goto :failed

echo [5/6] Running code analysis...
flutter analyze
if errorlevel 1 goto :analysis_failed

echo [6/6] Running tests...
flutter test
if errorlevel 1 goto :failed

echo.
echo Project preparation finished successfully.
echo Next: connect your Android phone and run 02_RUN_ON_PHONE.bat
pause
exit /b 0

:analysis_failed
echo.
echo Flutter found code issues. Copy the full error text and fix it before building.
pause
exit /b 1

:failed
echo.
echo Preparation failed. Copy the full error text from this window.
pause
exit /b 1
