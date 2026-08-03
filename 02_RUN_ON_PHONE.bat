@echo off
chcp 65001 >nul
cd /d "%~dp0"

echo ================================================
echo MASIR BALINI - RUN ON ANDROID PHONE

echo Make sure USB Debugging is enabled and the phone is connected.
echo ================================================

flutter devices
if errorlevel 1 goto :failed

echo.
flutter run
if errorlevel 1 goto :failed
exit /b 0

:failed
echo.
echo The app could not run. Copy the full error text.
pause
exit /b 1
