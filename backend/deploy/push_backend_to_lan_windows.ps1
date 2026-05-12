# Build backend .tgz and deploy to a Windows host in LAN over SSH (OpenSSH Server on Windows).
# Uses the same archive layout as push_backend_to_vps.ps1 (excludes node_modules, dist, .git, .env, uploads).
#
# Defaults match a monorepo at D:\обмен\ДА\MP with SSH Host "mp-servis" in %USERPROFILE%\.ssh\config.
# Override with parameters or environment:
#   MP_DEPLOY_SSH_TARGET    (e.g. mp-servis)
#   MP_DEPLOY_REMOTE_BACKEND
#   MP_DEPLOY_REMOTE_ARCHIVE  optional; default: <parent of backend>\mp-backend-deploy.tgz
#   MP_DEPLOY_SSH_KEY       optional path to key; if empty, ssh/scp use ~/.ssh/config only
#
# Examples:
#   cd C:\dev\MP\backend\deploy
#   .\push_backend_to_lan_windows.ps1
#   .\push_backend_to_lan_windows.ps1 -SshTarget mp-servis -RemoteBackend 'D:\work\MP\backend'
#   .\push_backend_to_lan_windows.ps1 -RestartMode None
#   .\push_backend_to_lan_windows.ps1 -RestartMode Service -ServiceName MpServisApi

param(
    [string] $SshTarget = "",
    [string] $RemoteBackend = "",
    [string] $RemoteArchive = "",
    [string] $SshKey = "",
    [ValidateSet('None', 'Service', 'NodeBackground')]
    [string] $RestartMode = 'NodeBackground',
    [string] $ServiceName = ''
)

$ErrorActionPreference = 'Stop'

if (-not $SshTarget) {
    $SshTarget = $env:MP_DEPLOY_SSH_TARGET
    if (-not $SshTarget) { $SshTarget = 'mp-servis' }
}
if (-not $RemoteBackend) {
    $RemoteBackend = $env:MP_DEPLOY_REMOTE_BACKEND
    if (-not $RemoteBackend) { $RemoteBackend = 'D:\обмен\ДА\MP\backend' }
}
if (-not $RemoteArchive) {
    $RemoteArchive = $env:MP_DEPLOY_REMOTE_ARCHIVE
    if (-not $RemoteArchive) {
        $mpRoot = Split-Path -Parent $RemoteBackend
        $RemoteArchive = Join-Path $mpRoot 'mp-backend-deploy.tgz'
    }
}

$runnerName = 'mp-backend-remote-lan-deploy.ps1'
$archiveParent = [System.IO.Path]::GetDirectoryName($RemoteArchive)
if ([string]::IsNullOrEmpty($archiveParent)) { throw "Cannot derive folder from RemoteArchive: $RemoteArchive" }
$RemoteRunner = [System.IO.Path]::Combine($archiveParent, $runnerName)

$backendRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$runnerLocal = Join-Path $PSScriptRoot 'remote_lan_windows_deploy.ps1'
if (-not (Test-Path -LiteralPath $runnerLocal)) { throw "Missing $runnerLocal" }

$tmp = [System.IO.Path]::GetTempFileName() + '.tgz'
Remove-Item -Force $tmp -ErrorAction SilentlyContinue

Push-Location $backendRoot
try {
    tar -czf $tmp --exclude=node_modules --exclude=dist --exclude=.git --exclude=.env --exclude=uploads .
    if ($LASTEXITCODE -ne 0) { throw 'tar failed' }
}
finally {
    Pop-Location
}

if (-not $SshKey) { $SshKey = $env:MP_DEPLOY_SSH_KEY }
$sshBase = @('-o', 'BatchMode=yes', '-o', 'ConnectTimeout=25')
if ($SshKey) {
    if (-not (Test-Path -LiteralPath $SshKey)) { throw "SshKey not found: $SshKey" }
    $sshBase = @('-i', $SshKey) + $sshBase
}

# scp/ssh target: Host from ssh config or user@host
$scpDestArchive = "${SshTarget}:$($RemoteArchive -replace '\\', '/')"
$scpDestRunner = "${SshTarget}:$($RemoteRunner -replace '\\', '/')"

$remoteArchiveDir = [System.IO.Path]::GetDirectoryName($RemoteArchive)
if (-not [string]::IsNullOrEmpty($remoteArchiveDir)) {
    $dirEsc = $remoteArchiveDir.Replace("'", "''")
    $mkdirLine = "New-Item -ItemType Directory -Force -LiteralPath '$dirEsc' | Out-Null"
    $mkdirEnc = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($mkdirLine))
    $mkdirShell = "powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand $mkdirEnc"
    Write-Host "Ensuring remote directory exists: $remoteArchiveDir" -ForegroundColor Cyan
    & ssh @sshBase $SshTarget $mkdirShell
    if ($LASTEXITCODE -ne 0) { throw 'ssh mkdir (remote archive dir) failed' }
}

Write-Host "Uploading archive to $scpDestArchive ..." -ForegroundColor Cyan
& scp @sshBase $tmp $scpDestArchive
if ($LASTEXITCODE -ne 0) { throw 'scp archive failed' }

Write-Host "Uploading remote runner to $scpDestRunner ..." -ForegroundColor Cyan
& scp @sshBase $runnerLocal $scpDestRunner
if ($LASTEXITCODE -ne 0) { throw 'scp runner failed' }

$scriptOnRemote = ($RemoteRunner -replace '\\', '/')
$bd = $RemoteBackend.Replace("'", "''")
$ar = $RemoteArchive.Replace("'", "''")
$sn = $ServiceName.Replace("'", "''")
$remoteLine = "& '$scriptOnRemote' -BackendDir '$bd' -ArchivePath '$ar' -RestartMode '$RestartMode' -ServiceName '$sn'"
$encBytes = [System.Text.Encoding]::Unicode.GetBytes($remoteLine)
$encoded = [Convert]::ToBase64String($encBytes)
$remoteShell = "powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand $encoded"

Write-Host 'Running remote build + migrations + restart ...' -ForegroundColor Cyan
& ssh @sshBase $SshTarget $remoteShell
if ($LASTEXITCODE -ne 0) { throw 'remote deploy failed' }

Remove-Item -Force $tmp -ErrorAction SilentlyContinue
Write-Host 'Done.' -ForegroundColor Green
