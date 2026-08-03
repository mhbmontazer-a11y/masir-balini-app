@echo off
chcp 65001 >nul
cd /d "%~dp0"
flutter clean
flutter pub get
flutter analyze
flutter test
pause
