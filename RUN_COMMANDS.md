# Команды для запуска

## 1. Бэкенд (NestJS)

Из корня проекта (`c:\dev\MP`):

```powershell
cd backend
npm install
npm run migration:run
npm run start:dev
```

После обновления кода из репозитория снова выполни `npm run migration:run`, если появились новые файлы в `backend\src\database\migrations` — иначе при входе возможна ошибка вроде «отношение user_organization_memberships не существует».

Бэкенд будет доступен по адресу `http://localhost:3000` (API: `http://localhost:3000/api/v1`).

**Важно:** если телефон и ПК в одной Wi‑Fi сети, в клиентских приложениях в `app_config.dart` должен быть LAN IP ПК с бэкендом; по умолчанию задано `192.168.1.187`. При другом адресе измени `defaultValue` или передай `--dart-define=MP_SERVIS_API_HOST=...` (узнать IP: `ipconfig` → IPv4).

---

## 2. Flutter: установка на телефон

Подключи телефон по USB, включи отладку по USB. Затем:

### Бизнес-приложение (для СТО)

```powershell
cd c:\dev\MP\autohub_business
flutter pub get
flutter run
```

### Клиентское приложение

```powershell
cd c:\dev\MP\autohub_client2
flutter pub get
flutter run
```

Если подключено несколько устройств, выбери нужное в списке или укажи id:

```powershell
flutter devices
flutter run -d <device_id>
```

---

## 3. Переустановка (чистая установка)

Чтобы снести приложение с телефона и поставить заново:

```powershell
cd c:\dev\MP\autohub_business
flutter clean
flutter pub get
flutter run
```

Аналогично для клиента:

```powershell
cd c:\dev\MP\autohub_client2
flutter clean
flutter pub get
flutter run
```

`flutter run` сам установит и запустит приложение на выбранном устройстве.

---

## 4. iOS (только на Mac)

Полного аналога `*.bat` на **Windows** для iOS нет: сборка и подпись требуют **Xcode** и участия в **Apple Developer Program** (или бесплатную подпись для своего устройства с ограничениями).

В каталогах `autohub_client2` и `autohub_business` на Mac:

```bash
chmod +x build_ios_release.sh run_ios_device.sh
```

**Release IPA** (как `build_android_release.bat`):

```bash
cd autohub_client2   # или autohub_business
./build_ios_release.sh
```

Результат: `build/ios/ipa/*.ipa` — дальше **TestFlight** / **Transporter** / App Store, а не «перекинуть файл» на чужой iPhone как APK.

**Запуск на подключённом iPhone** (аналог `run_*_phone.bat`):

```bash
./run_ios_device.sh
# локальный Nest без dart-define прод-API:
USE_LAN_API=1 ./run_ios_device.sh
```

Перед первым запуском: открыть `ios/Runner.xcworkspace` в Xcode, выбрать **Team** (Signing & Capabilities), на телефоне включить режим разработчика / доверие к сертификату.
