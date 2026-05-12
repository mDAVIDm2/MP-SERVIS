#!/usr/bin/env bash
# MP-Servis Client — release IPA (только macOS + Xcode + Apple Developer).
# В отличие от APK: нельзя собрать на Windows; установка на iPhone — через TestFlight,
# Ad Hoc (UDID в профиле) или кабель: ./run_ios_device.sh
set -euo pipefail
cd "$(dirname "$0")"

ARGS=(--dart-define=MP_SERVIS_API_BASE_URL=https://api.mp-servis.ru/api/v1)
if [[ -f config/partner_osago_define.json ]]; then
  ARGS+=(--dart-define-from-file=config/partner_osago_define.json)
fi
if [[ -f config/firebase_define.json ]]; then
  ARGS+=(--dart-define-from-file=config/firebase_define.json)
fi

echo "flutter build ipa --release ${ARGS[*]}"
flutter pub get
flutter build ipa --release "${ARGS[@]}"

echo ""
echo "IPA: build/ios/ipa/*.ipa"
echo "Дальше: загрузить в App Store Connect (Transporter / Xcode) или раздать тестерам через TestFlight."
echo "Для push: положите GoogleService-Info.plist в ios/Runner/ (см. Firebase для iOS)."
