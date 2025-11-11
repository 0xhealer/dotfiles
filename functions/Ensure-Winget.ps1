# functions/Ensure-Winget.ps1
<#
.SYNOPSIS
  Ensures Winget (App Installer) is present and ready for unattended use.

.DESCRIPTION
  - Detects whether `winget` exists. If missing and Chocolatey is available, installs winget via choco (silent).
  - Verifies & repairs winget sources:
      * Ensures the default 'winget' CDN is present.
      * Ensures the Microsoft Store source 'msstore' is present (when supported).
      * Forces a source reset/update to clear corrupted caches.
  - Warms up winget by running a no-op query so first real use is faster.
  - Designed to be idempotent and fully non-interactive.

.NOTES
  - On modern Windows 11, winget ships with **App Installer**. If neither winget nor choco are present,
    we cannot bootstrap the Microsoft Store programmatically; in that case the function throws with a helpful error.
  - This module does not perform any package installs; it only guarantees winget is usable.

.EXAMPLE
  Ensure-Winget
#>
function Ensure-Winget {
  [CmdletBinding()]
  param()

  Set-StrictMode -Version Latest
  $ErrorActionPreference = 'Continue'

  function _Test-Command([string]$Name) {
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
  }

  # Try to enable TLS 1.2 for any downloads done by child tools
  try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
  }
  catch { }

  # 1) Ensure winget exists (install via choco if possible)
  if (-not (_Test-Command 'winget')) {
    Write-Host "[winget] Not found. Attempting silent install via Chocolatey..." -ForegroundColor Cyan

    if (_Test-Command 'choco') {
      try {
        choco install winget -y --no-progress | Out-Null
      }
      catch {
        throw "Chocolatey failed to install winget: $($_.Exception.Message)"
      }
    }
    else {
      # Last resort: App Installer must be obtained from the Microsoft Store (unattended MS Store bootstrap isn't reliable).
      throw "Winget is not available and Chocolatey is not installed. Install 'App Installer' from the Microsoft Store or ensure 'winget.exe' is on PATH, then re-run."
    }

    if (-not (_Test-Command 'winget')) {
      throw "Winget still not found after Chocolatey installation."
    }

    Write-Host "[winget] Installed." -ForegroundColor Green
  }
  else {
    Write-Host "[winget] Found on PATH." -ForegroundColor DarkGray
  }

  # 2) Verify & repair sources
  Write-Host "[winget] Verifying sources..." -ForegroundColor Cyan

  # Helper to get current sources (returns names)
  function _Get-WingetSources {
    $names = @()
    $out = winget source list 2>$null
    if ($LASTEXITCODE -eq 0 -and $out) {
      foreach ($line in $out) {
        # Typical output: "Name    Argument                                      Type"
        # Followed by lines like: "winget  https://cdn.winget.microsoft.com/cache     Microsoft.Rest"
        if ($line -match '^\s*([^\s]+)\s+(\S+)\s+') {
          $names += $matches[1]
        }
      }
    }
    return $names
  }

  $sourcesBefore = _Get-WingetSources

  # Ensure 'winget' CDN source exists
  if (-not ($sourcesBefore -contains 'winget')) {
    try {
      winget source add --name winget --arg https://cdn.winget.microsoft.com/cache --type Microsoft.PreIndexed.Package 2>$null | Out-Null
    }
    catch {
      # Ignore if add fails; we'll reset next
    }
  }

  # Ensure 'msstore' exists when supported (may fail on systems without Store integration)
  if (-not ($sourcesBefore -contains 'msstore')) {
    try {
      winget source add --name msstore --arg ms-store: 2>$null | Out-Null
    }
    catch {
      # Some editions block msstore; that's fine.
    }
  }

  # Force reset/update to clean any stale/corrupt catalogs
  try { winget source reset --force 2>$null | Out-Null } catch { }
  try { winget source update 2>$null | Out-Null } catch { }

  # 3) Warm up (first run builds SQLite catalogs; do a quick query)
  try { winget list --accept-source-agreements --accept-package-agreements >/nul 2>&1 } catch { }

  Write-Host "[winget] Ready for unattended installs." -ForegroundColor Green
}
