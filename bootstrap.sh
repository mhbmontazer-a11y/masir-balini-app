#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
cp pubspec.yaml pubspec.masir.backup.yaml
flutter create --platforms=android,ios --org ir.masirbalini --project-name masir_balini .
cp pubspec.masir.backup.yaml pubspec.yaml
rm pubspec.masir.backup.yaml
flutter pub get
dart run flutter_launcher_icons
flutter analyze
flutter test
