@echo off
set "RUN_EXIT=0"

echo ========================================
echo   MP-Servis Business - Windows desktop
echo ========================================
echo.

cd /d "%~dp0autohub_business"
if errorlevel 1 (
  echo ERROR - Cannot cd to autohub_business.
  set "RUN_EXIT=1"
  goto :final
)
if not exist "pubspec.yaml" (
  echo ERROR - pubspec.yaml missing in autohub_business.
  set "RUN_EXIT=1"
  goto :final
)

where flutter >nul 2>&1
if errorlevel 1 (
  echo ERROR - flutter not in PATH.
  set "RUN_EXIT=9001"
  goto :final
)

echo flutter pub get...
call flutter pub get
if errorlevel 1 (
  set "RUN_EXIT=%errorlevel%"
  goto :final
)

rem firebase_core on Windows needs Firebase C++ SDK (~912 MB). Prep script runs once.
if not exist "build\windows\x64\extracted\firebase_cpp_sdk_windows\CMakeLists.txt" (
  echo.
  echo First Windows run - preparing Firebase C++ SDK ^(large download, curl^).
  echo On ZIP errors run manually - tool\prep_firebase_cpp_windows.ps1
  echo.
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0autohub_business\tool\prep_firebase_cpp_windows.ps1"
  if errorlevel 1 (
    echo ERROR - Firebase SDK prep failed.
    set "RUN_EXIT=1"
    goto :final
  )
  echo.
)

call flutter run -d windows
set "RUN_EXIT=%errorlevel%"

:final
echo.
if not "%RUN_EXIT%"=="0" (
  echo Finished with error, code %RUN_EXIT%.
) else (
  echo flutter run finished OK.
)
echo.
if "%NO_PAUSE%"=="1" exit /b %RUN_EXIT%
echo Press any key to close...
pause
exit /b %RUN_EXIT%
