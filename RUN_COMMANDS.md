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

**Важно:** если телефон и ПК в одной Wi‑Fi сети, в клиентских приложениях в `app_config.dart` должен быть LAN IP ПК с бэкендом; по умолчанию задано `10.56.161.14`. При другом адресе измени `defaultValue` или передай `--dart-define=AUTOHUB_API_HOST=...` (узнать IP: `ipconfig` → IPv4).

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
