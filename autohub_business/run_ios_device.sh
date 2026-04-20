#!/usr/bin/env bash
# MP-Servis Business — запуск на подключённом iPhone/iPad.
set -euo pipefail
cd "$(dirname "$0")"

ARGS=()
if [[ "${USE_LAN_API:-}" == "1" ]]; then
  echo "API: LAN"
else
  ARGS+=(--dart-define=MP_SERVIS_API_BASE_URL=https://api.mp-servis.ru/api/v1)
fi
if [[ -f config/firebase_define.json ]]; then
  ARGS+=(--dart-define-from-file=config/firebase_define.json)
fi

echo "Подключите устройство, откройте ios/Runner.xcworkspace в Xcode при первой настройке подписи."
flutter pub get
flutter run "${ARGS[@]}"
