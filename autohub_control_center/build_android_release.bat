@echo off
setlocal
cd /d "%~dp0"

set "ARGS=--dart-define=MP_SERVIS_API_BASE_URL=https://api.mp-servis.ru/api/v1"

echo flutter build apk --release %ARGS%
flutter build apk --release %ARGS%

echo.
echo APK: build\app\outputs\flutter-apk\app-release.apk
if not exist "android\key.properties" (
  echo.
  echo ВНИМАНИЕ: нет android\key.properties — APK подписан debug-ключом ^(для теста^).
  echo Для публикации в Google Play настройте release-подпись.
)
endlocal
