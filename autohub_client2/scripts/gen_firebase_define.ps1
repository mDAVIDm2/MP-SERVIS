$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$gs = Join-Path $root "android\app\google-services.json"
if (-not (Test-Path $gs)) {
    Write-Host "Нет файла: $gs"
    Write-Host "Скачайте google-services.json в Firebase Console (Project settings → Your apps → Android)."
    exit 1
}
Set-Location $root
dart run tool/google_services_to_dart_define.dart android/app/google-services.json
