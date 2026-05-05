# MP-Servis backend install from migration bundle (Windows Server).
# PowerShell 5.1+. ASCII messages only (encoding-safe).
#
# Layout A (default): InstallRoot = parent folder, repo at "<InstallRoot>\MP"
# Layout B: -MonorepoRootIsInstallRoot — repo root IS InstallRoot (e.g. D:\obmen\DA\MP)
#
param(
    [Parameter(Mandatory = $true)]
    [string] $RepoUrl,
    [string] $InstallRoot = "C:\mp-servis",
    [string] $PostgresBin = "",
    [string] $MigrationBundlePath = "",
    [switch] $MonorepoRootIsInstallRoot,
    [switch] $SkipClone,
    [switch] $SkipDatabaseRestore
)

$ErrorActionPreference = "Stop"
if ($MigrationBundlePath) {
    $Bundle = $MigrationBundlePath
}
else {
    $Bundle = $PSScriptRoot
}
if ($MonorepoRootIsInstallRoot) {
    $MP = $InstallRoot
}
else {
    $MP = Join-Path $InstallRoot "MP"
}
$Backend = Join-Path $MP "backend"

function Get-DatabaseUrlFromEnv {
    param([string] $EnvPath)
    foreach ($line in Get-Content $EnvPath -Encoding UTF8) {
        if ($line -match '^\s*DATABASE_URL=(.+)$') {
            return $Matches[1].Trim()
        }
    }
    throw "DATABASE_URL not found in .env"
}

if (-not $PostgresBin) {
    $pgBins = Get-ChildItem "C:\Program Files\PostgreSQL" -Directory -ErrorAction SilentlyContinue |
        ForEach-Object {
            $exe = Join-Path $_.FullName "bin\pg_restore.exe"
            if (Test-Path $exe) { [PSCustomObject]@{ Dir = $_.FullName; Ver = $_.Name } }
        } |
        Sort-Object { [int]($_.Ver -replace '\D', '') } -Descending
    $best = $pgBins | Select-Object -First 1
    if ($best) { $PostgresBin = Join-Path $best.Dir "bin" }
}
if (-not $PostgresBin -or -not (Test-Path (Join-Path $PostgresBin "pg_restore.exe"))) {
    throw "pg_restore not found. Pass -PostgresBin, e.g. C:\Program Files\PostgreSQL\18\bin"
}

$pgRestore = Join-Path $PostgresBin "pg_restore.exe"
$dropdb = Join-Path $PostgresBin "dropdb.exe"
$createdb = Join-Path $PostgresBin "createdb.exe"

Write-Host "=== 1. Git clone ===" -ForegroundColor Cyan
if (-not $SkipClone) {
    $gitDir = Join-Path $MP ".git"
    if (Test-Path $gitDir) {
        Write-Host "Git repo exists: $MP (git pull if needed)"
        Push-Location $MP
        try { git pull } finally { Pop-Location }
    }
    else {
        $items = @(Get-ChildItem -LiteralPath $MP -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -notin @('.', '..') })
        if ($items.Count -gt 0) {
            throw "Cannot git clone: $MP is not empty. Move other folders out, then re-run, or clone manually and use -SkipClone."
        }
        New-Item -ItemType Directory -Path $MP -Force | Out-Null
        git clone $RepoUrl $MP
    }
}
else {
    Write-Host "SkipClone: assuming repo already at $MP"
}

if (-not (Test-Path $Backend)) { throw "Missing backend folder: $Backend" }

Write-Host "=== 2. .env ===" -ForegroundColor Cyan
Copy-Item (Join-Path $Bundle ".env.from_vps") (Join-Path $Backend ".env") -Force
Write-Host "Edit backend\.env: API_BASE_URL, ALLOWED_ORIGINS, DATABASE_URL, PORT if 3000 is busy."

Write-Host "=== 3. uploads + secrets ===" -ForegroundColor Cyan
Push-Location $Backend
try {
    if (Test-Path (Join-Path $Bundle "mp_servis_uploads.tgz")) {
        tar -xzf (Join-Path $Bundle "mp_servis_uploads.tgz")
    }
    if (Test-Path (Join-Path $Bundle "mp_secrets.tgz")) {
        tar -xzf (Join-Path $Bundle "mp_secrets.tgz")
    }
}
finally {
    Pop-Location
}

if (-not $SkipDatabaseRestore) {
    Write-Host "=== 4. Database restore (drop/create DB, pg_restore) ===" -ForegroundColor Cyan
    $envPath = Join-Path $Backend ".env"
    $dbUrl = Get-DatabaseUrlFromEnv -EnvPath $envPath
    $dump = Join-Path $Bundle "mp_servis_full.dump"
    if (-not (Test-Path $dump)) { throw "Missing dump file: $dump" }

    if ($dbUrl -match '/([^/?]+)(?:\?|$)') {
        $dbName = $Matches[1]
    }
    else {
        $dbName = "mp_servis"
    }

    $env:PGPASSWORD = $null
    if ($dbUrl -match 'postgresql://([^:]+):([^@]+)@') {
        $pgUser = $Matches[1]
        $env:PGPASSWORD = $Matches[2]
    }
    elseif ($dbUrl -match 'postgresql://([^@]+)@') {
        $pgUser = $Matches[1]
    }

    if (-not $pgUser) { $pgUser = "postgres" }

    & $dropdb -U $pgUser --if-exists $dbName 2>$null
    & $createdb -U $pgUser $dbName
    & $pgRestore -d $dbUrl --verbose --no-owner --no-acl $dump
    $env:PGPASSWORD = $null
}
else {
    Write-Host "=== 4. Database restore SKIPPED (SkipDatabaseRestore) ===" -ForegroundColor Yellow
}

Write-Host "=== 5. npm ci / build ===" -ForegroundColor Cyan
Push-Location $Backend
try {
    npm ci
    if ($LASTEXITCODE -ne 0) { throw "npm ci failed with exit code $LASTEXITCODE" }
    npm run build
    if ($LASTEXITCODE -ne 0) { throw "npm run build failed with exit code $LASTEXITCODE" }
    if (-not $SkipDatabaseRestore) {
        npm run migration:run:prod
        if ($LASTEXITCODE -ne 0) {
            Write-Host "migration:run:prod exit code $LASTEXITCODE (often OK after full pg_restore)." -ForegroundColor Yellow
        }
    }
}
finally {
    Pop-Location
}

Write-Host ""
Write-Host "Done. Start API: cd `"$Backend`"; `$env:PORT='3001'; npm run start   # set PORT if 3000 is in use" -ForegroundColor Green
Write-Host "Note: npm run start runs prestart kill-port on PORT (default 3000). Set PORT in shell if needed."
Write-Host "Set reverse-proxy to http://127.0.0.1:<PORT> and verify .env."
