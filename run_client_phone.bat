@echo off
chcp 65001 >nul 2>&1
set "RUN_EXIT=0"

echo ========================================
echo   AutoHub Client - запуск на телефон
echo ========================================
echo.
echo Подключите телефон по USB или запустите эмулятор.
echo.

cd /d "%~dp0autohub_client2"
if errorlevel 1 (
  echo Ошибка: не удалось перейти в папку autohub_client2.
  set "RUN_EXIT=1"
  goto :final
)
if not exist "pubspec.yaml" (
  echo Ошибка: нет pubspec.yaml в autohub_client2.
  set "RUN_EXIT=1"
  goto :final
)

call flutter run
set "RUN_EXIT=%errorlevel%"

:final
echo.
if not "%RUN_EXIT%"=="0" (
  echo Завершено с ошибкой (код %RUN_EXIT%).
) else (
  echo Сессия flutter run завершена (код 0).
)
echo.
echo Нажмите любую клавишу, чтобы закрыть окно...
pause
exit /b %RUN_EXIT%
