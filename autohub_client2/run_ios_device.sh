#!/usr/bin/env bash
# MP-Servis Client — запуск на подключённом iPhone/iPad (USB или сеть), debug/profile.
# Требуется: Mac, Xcode, подпись Team в ios/Runner.xcworkspace, доверие к разработчику на устройстве.
set -euo pipefail
cd "$(dirname "$0")"

ARGS=()
if [[ "${USE_LAN_API:-}" == "1" ]]; then
  echo "API: LAN (как в USE_LAN_API=1 для Android)"
else
  ARGS+=(--dart-define=MP_SERVIS_API_BASE_URL=https://api.mp-servis.ru/api/v1)
fi
if [[ -f config/firebase_define.json ]]; then
  ARGS+=(--dart-define-from-file=config/firebase_define.json)
fi

echo "Подключите устройство, разблокируйте экран, примите запрос «Доверять этому компьютеру»."
flutter pub get
flutter run "${ARGS[@]}"
