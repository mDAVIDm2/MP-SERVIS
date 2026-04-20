#!/usr/bin/env bash
# MP-Servis Business — release IPA (только macOS + Xcode + Apple Developer).
set -euo pipefail
cd "$(dirname "$0")"

ARGS=(--dart-define=MP_SERVIS_API_BASE_URL=https://api.mp-servis.ru/api/v1)
if [[ -f config/firebase_define.json ]]; then
  ARGS+=(--dart-define-from-file=config/firebase_define.json)
fi

echo "flutter build ipa --release ${ARGS[*]}"
flutter pub get
flutter build ipa --release "${ARGS[@]}"

echo ""
echo "IPA: build/ios/ipa/*.ipa"
echo "Дальше: Transporter / Xcode → App Store Connect или TestFlight."
