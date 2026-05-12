# Сборка архива из backend/ (без node_modules, dist, .env, uploads) и выкладка на VPS.
# Требуется: OpenSSH (ssh, scp), ключ по умолчанию: $env:USERPROFILE\.ssh\id_ed25519_mp_servis_vps
#
# Пример:
#   cd C:\dev\MP\backend\deploy
#   .\push_backend_to_vps.ps1
#   .\push_backend_to_vps.ps1 -VpsHost 217.114.0.114

param(
    [string] $VpsHost = "217.114.0.114",
    [string] $VpsUser = "root",
    [string] $SshKey = "",
    [string] $RemoteArchive = "/tmp/mp-backend-deploy.tgz"
)

$ErrorActionPreference = "Stop"
$backendRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
if ($SshKey -eq "") { $SshKey = Join-Path $env:USERPROFILE ".ssh\id_ed25519_mp_servis_vps" }
if (-not (Test-Path $SshKey)) { throw "Нет ключа: $SshKey" }

$tmp = [System.IO.Path]::GetTempFileName() + ".tgz"
Remove-Item -Force $tmp -ErrorAction SilentlyContinue

Push-Location $backendRoot
try {
    tar -czf $tmp --exclude=node_modules --exclude=dist --exclude=.git --exclude=.env --exclude=uploads .
    if ($LASTEXITCODE -ne 0) { throw "tar failed" }
} finally {
    Pop-Location
}

# scp: только -i и опции; user@host — в конце как remote:path
$sshOpts = @("-i", $SshKey, "-o", "BatchMode=yes")
$ssh = $sshOpts + @("${VpsUser}@${VpsHost}")
Write-Host "Uploading to ${VpsUser}@${VpsHost}:${RemoteArchive} ..."
& scp @sshOpts $tmp "${VpsUser}@${VpsHost}:${RemoteArchive}"
if ($LASTEXITCODE -ne 0) { throw "scp failed" }

# Только LF: не использовать here-string из файла с BOM/CRLF — bash на Linux ломается.
$remoteLines = @(
    'set -euo pipefail',
    'API_DIR=/opt/mp-servis/api',
    'ARCHIVE=/tmp/mp-backend-deploy.tgz',
    'systemctl stop mp-servis-api || true',
    'cd "$API_DIR"',
    'sudo -u mpservis tar -xzf "$ARCHIVE"',
    'chown -R mpservis:mpservis "$API_DIR"',
    'sudo -u mpservis bash -lc "cd $API_DIR && npm ci && npm run build && npm run migration:run:prod && npm prune --omit=dev"',
    'systemctl start mp-servis-api',
    'sleep 2',
    'systemctl is-active mp-servis-api',
    'curl -sS -o /dev/null -w "HTTP %{http_code}\n" "http://127.0.0.1:3000/api/v1/reference/car-brands" || true'
)
$remoteScript = (($remoteLines | ForEach-Object { $_ -replace "`r", "" }) -join "`n").TrimEnd() + "`n"
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$tmpSh = [System.IO.Path]::GetTempFileName() + "_deploy.sh"
try {
    [System.IO.File]::WriteAllText($tmpSh, $remoteScript, $utf8NoBom)
    Write-Host "Remote build + migrations + restart ..."
    $remoteShPath = "/tmp/mp-backend-deploy-remote.sh"
    & scp @sshOpts $tmpSh "${VpsUser}@${VpsHost}:${remoteShPath}"
    if ($LASTEXITCODE -ne 0) { throw "scp remote script failed" }
    & ssh @ssh "chmod +x $remoteShPath && bash $remoteShPath && rm -f $remoteShPath"
    if ($LASTEXITCODE -ne 0) { throw "remote script failed" }
} finally {
    Remove-Item -LiteralPath $tmpSh -Force -ErrorAction SilentlyContinue
}

Remove-Item -Force $tmp -ErrorAction SilentlyContinue
Write-Host "Done."
