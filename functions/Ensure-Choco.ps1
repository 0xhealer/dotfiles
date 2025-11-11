# functions/Ensure-Choco.ps1
<#
.SYNOPSIS
  Ensures Chocolatey is installed and configured for fully unattended use.

.DESCRIPTION
  - Detects whether `choco` is available. If not, installs Chocolatey silently.
  - Sets sane, non-interactive defaults so future `choco` commands run without prompts:
      * allowGlobalConfirmation (auto -y)
      * useEnhancedExitCodes
      * logEnvironmentValues (off)
      * showDownloadProgress (off)
  - Upgrades Chocolatey to the latest stable version if an outdated build is detected.
  - Idempotent: safe to run multiple times.

.NOTES
  - Requires internet access to bootstrap Chocolatey when it isn't present.
  - Designed to be imported and auto-run by your install.ps1 (no user interaction).
#>
function Ensure-Choco {
  [CmdletBinding()]
  param()

  Set-StrictMode -Version Latest
  $ErrorActionPreference = 'Continue'

  # Helper: test command existence
  function _Test-Command([string]$Name) {
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
  }

  # Enable TLS 1.2 for bootstrap
  try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
  }
  catch { }

  if (-not (_Test-Command 'choco')) {
    Write-Host "[choco] Installing Chocolatey (silent)..." -ForegroundColor Cyan
    # Official unattended bootstrap (no prompts)
    $script = 'Set-ExecutionPolicy Bypass -Scope Process -Force; ' +
    '[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12; ' +
    'iex ((New-Object System.Net.WebClient).DownloadString(''https://community.chocolatey.org/install.ps1''))'
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command $script | Out-Null

    if (-not (_Test-Command 'choco')) {
      throw "Chocolatey installation failed or 'choco' not found on PATH after install."
    }

    Write-Host "[choco] Installed." -ForegroundColor Green
  }
  else {
    Write-Host "[choco] Found on PATH." -ForegroundColor DarkGray
  }

  # Configure for fully unattended operation
  Write-Host "[choco] Ensuring non-interactive defaults..." -ForegroundColor Cyan
  choco feature enable -n=allowGlobalConfirmation       | Out-Null  # implies -y globally
  choco feature enable -n=useEnhancedExitCodes          | Out-Null
  choco feature disable -n=logEnvironmentValues         | Out-Null
  choco feature disable -n=showDownloadProgress         | Out-Null

  # Keep Chocolatey itself current (quiet)
  try {
    choco upgrade chocolatey -y --no-progress | Out-Null
    Write-Host "[choco] Up-to-date." -ForegroundColor DarkGray
  }
  catch {
    Write-Host "[choco] Upgrade check failed: $($_.Exception.Message)" -ForegroundColor DarkYellow
  }
}
