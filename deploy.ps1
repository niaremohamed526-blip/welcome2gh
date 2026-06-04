<#
.SYNOPSIS
    Build the Flutter web app and deploy it to Vercel via GitHub.

.DESCRIPTION
    Runs the full upgrade loop in one command:
      1. (optional) flutter analyze + flutter test
      2. flutter build web --release
      3. sync the fresh build into public/  (what Vercel serves)
      4. git add / commit / push   ->  Vercel auto-deploys

.PARAMETER Message
    The git commit message. If omitted, a timestamped message is used.

.PARAMETER SkipChecks
    Skip "flutter analyze" and "flutter test" (faster, less safe).

.EXAMPLE
    .\deploy.ps1 "Fix map zoom buttons"

.EXAMPLE
    .\deploy.ps1            # uses an auto timestamped message

.EXAMPLE
    .\deploy.ps1 "quick tweak" -SkipChecks
#>
param(
    [Parameter(Position = 0)]
    [string]$Message = "",
    [switch]$SkipChecks
)

$ErrorActionPreference = "Stop"

# Always run from the script's own folder (the repo root).
Set-Location -Path $PSScriptRoot

function Step($text) { Write-Host "`n==> $text" -ForegroundColor Cyan }
function Fail($text) { Write-Host "`nX  $text" -ForegroundColor Red; exit 1 }

if ([string]::IsNullOrWhiteSpace($Message)) {
    $Message = "Update web build - " + (Get-Date -Format "yyyy-MM-dd HH:mm")
}

# 1. Quality gates -----------------------------------------------------------
if (-not $SkipChecks) {
    Step "Analyzing (flutter analyze)"
    flutter analyze
    if ($LASTEXITCODE -ne 0) { Fail "Analyzer found issues. Fix them or rerun with -SkipChecks." }

    Step "Running tests (flutter test)"
    flutter test
    if ($LASTEXITCODE -ne 0) { Fail "Tests failed. Fix them or rerun with -SkipChecks." }
}
else {
    Step "Skipping analyze + tests (-SkipChecks)"
}

# 2. Build -------------------------------------------------------------------
Step "Building web release (flutter build web --release)"
flutter build web --release
if ($LASTEXITCODE -ne 0) { Fail "Web build failed." }
if (-not (Test-Path "build\web\index.html")) { Fail "build\web\index.html missing - build did not produce output." }

# 3. Sync the build into public/ (Vercel serves this folder) -----------------
Step "Syncing build\web -> public\"
if (Test-Path "public") { Remove-Item -Recurse -Force "public" }
New-Item -ItemType Directory -Path "public" | Out-Null
Copy-Item -Recurse -Force "build\web\*" "public\"

# 4. Commit + push -----------------------------------------------------------
Step "Committing and pushing"
git add -A

# Nothing staged? Then there is nothing to deploy.
git diff --cached --quiet
if ($LASTEXITCODE -eq 0) {
    Write-Host "Nothing changed - working tree is already deployed. Skipping commit." -ForegroundColor Yellow
    exit 0
}

git commit -m $Message
if ($LASTEXITCODE -ne 0) { Fail "git commit failed." }

git push
if ($LASTEXITCODE -ne 0) { Fail "git push failed (check your network / GitHub auth)." }

Write-Host "`nDeployed. Vercel will publish the new build in ~30-60s." -ForegroundColor Green
Write-Host "   Commit message: $Message" -ForegroundColor DarkGray
