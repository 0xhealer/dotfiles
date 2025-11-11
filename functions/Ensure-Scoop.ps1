# functions/Ensure-Scoop.ps1
<#
.SYNOPSIS
  Ensures Scoop is installed and configured for fully unattended use.

.DESCRIPTION
  - Detects whether `scoop` exists; if not, installs Scoop silently for the current user.
  - Sets sane, non-interactive defaults:
      * Ensures execution policy is compatible (CurrentUser: RemoteSigned).
      * Adds common buckets ('main', 'extras') if missing.
      * Enables aria2 for faster downloads and tunes its settings.
  - Updates Scoop and buckets so future installs are fresh.
  - Idempotent: safe to run multiple times.

.NOTES
  - Installs Scoop in the user profile (no admin required once bootstrap is elevated).
  - Does NOT install any apps; only prepares Scoop itself.
  - If corporate policy blocks script download, this will throw with a clear error.
#>
function Ensure-Scoop {
  [CmdletBinding()]
  param()

  Set-StrictMode -Version Latest
  $ErrorActionPreference = 'Continue'

  function _Test-Command([string]$Name) {
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
  }

  # Ensure TLS 1.2 for bootstrap downloads
  try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
  }
  catch { }

  # Make sure the CurrentUser execution policy allows local scripts
  try {
    $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser -ErrorAction SilentlyContinue
    if (-not $currentPolicy -or $currentPolicy -eq 'Undefined' -or $currentPolicy -eq 'Restricted') {
      Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force -ErrorAction Stop
    }
  }
  catch {
    Write-Warning "Failed to set CurrentUser execution policy: $($_.Exception.Message)"
    # continue regardless; Process scope is already Bypass in install.ps1
  }

  # 1) Install Scoop if missing
  if (-not (_Test-Command 'scoop')) {
    Write-Host "[scoop] Installing Scoop (user scope)..." -ForegroundColor Cyan
    try {
      # Official bootstrap
      Invoke-WebRequest -useb get.scoop.sh | Invoke-Expression
    }
    catch {
      throw "Scoop installation failed: $($_.Exception.Message)"
    }

    if (-not (_Test-Command 'scoop')) {
      throw "Scoop not found on PATH after installation."
    }

    Write-Host "[scoop] Installed." -ForegroundColor Green
  }
  else {
    Write-Host "[scoop] Found on PATH." -ForegroundColor DarkGray
  }

  # 2) Add common buckets if missing
  Write-Host "[scoop] Ensuring buckets..." -ForegroundColor Cyan
  $bucketList = & scoop bucket list 2>$null
  $hasMain = ($bucketList -match '^\s*main\s')
  $hasExtras = ($bucketList -match '^\s*extras\s')
  $hasVersions = ($bucketList -match '^\s*versions\s')
  $hasSysInternals = ($bucketList -match '^\s*sysinternals\s')



  if (-not $hasMain) {
    try { scoop bucket add main | Out-Null } catch { Write-Warning "Failed to add 'main' bucket: $($_.Exception.Message)" }
  }
  if (-not $hasExtras) {
    try { scoop bucket add extras | Out-Null } catch { Write-Warning "Failed to add 'extras' bucket: $($_.Exception.Message)" }
  }
  if (-not $hasVersions) {
    try { scoop bucket add versions | Out-Null } catch { Write-Warning "Failed to add 'versions' bucket: $($_.Exception.Message)" }
  }
  if (-not $hasSysInternals) {
    try { scoop bucket add sysinternals | Out-Null } catch { Write-Warning "Failed to add 'sysinternals' bucket: $($_.Exception.Message)" }
  }

  # 3) Enable aria2 (faster, parallel downloads) and tune settings
  Write-Host "[scoop] Enabling aria2 and tuning settings..." -ForegroundColor Cyan
  try {
    scoop config aria2-enabled true           | Out-Null
    scoop config aria2-retry-wait 2           | Out-Null
    scoop config aria2-split 8                | Out-Null
    scoop config aria2-max-connection-per-server 8 | Out-Null
    scoop config aria2-min-split-size 5M      | Out-Null
  }
  catch {
    Write-Warning "Failed to configure aria2: $($_.Exception.Message)"
  }

  # 4) Update Scoop and buckets quietly
  try {
    scoop update | Out-Null
    Write-Host "[scoop] Updated and ready." -ForegroundColor Green
  }
  catch {
    Write-Warning "Scoop update failed: $($_.Exception.Message)"
  }
}
