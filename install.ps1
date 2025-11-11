<#
.SYNOPSIS
  Thin bootstrap for Windows 11 dotfiles — calls only functions/core.ps1.

.DESCRIPTION
  This script does just the minimal orchestration:
    - Ensures elevation and sets a process-scoped execution policy.
    - Starts a transcript in .\logs and resolves repo root.
    - Loads ONLY .\functions\core.ps1.
    - Hands off to the single entrypoint defined there: Invoke-DotfilesSetup.
  All other functions (Ensure-Winget/Choco/Scoop, Install-WingetApps, Copy-Configs, etc.)
  MUST be invoked by core.ps1, not here.

.PARAMETER Primary
  Preferred package manager (winget|choco|scoop). Default: winget. Passed to core.ps1.

.PARAMETER Fallback
  Fallback package manager (winget|choco|scoop). Default: choco. Passed to core.ps1.

.PARAMETER RequiredPackagesPath
  Path to required-packages.json (names only). Default: .\packages\required-packages.json

.PARAMETER WindowsPackagesPath
  Path to windows-packages.json (reference metadata). Default: .\packages\windows-packages.json

.PARAMETER FontsPath
  Folder containing fonts. Default: .\fonts

.PARAMETER ConfigsPath
  Folder containing configs. Default: .\configs

.PARAMETER WallpaperPath
  Wallpaper folder or file. Default: .\wallpapers

.PARAMETER LogDir
  Directory for transcript logs. Default: .\logs

.PARAMETER SkipPackages
  Skip package installation (core decides what that means).

.PARAMETER SkipFonts
  Skip font installation.

.PARAMETER SkipConfigs
  Skip config deployment.

.PARAMETER SkipWallpaper
  Skip wallpaper setup.

.PARAMETER AllowUserScopeRetry
  Hint for installers to retry with user scope when machine scope fails (core decides when).

.PARAMETER Update
  Optional flag forwarded to core for any self-update behaviors.
#>

[CmdletBinding()]
param(
  [ValidateSet('winget', 'choco', 'scoop')]
  [string]$Primary = 'winget',

  [ValidateSet('winget', 'choco', 'scoop')]
  [string]$Fallback = 'choco',

  [string]$RequiredPackagesPath = '.\packages\required-packages.json',
  [string]$WindowsPackagesPath = '.\packages\windows-packages.json',
  [string]$FontsPath = '.\fonts',
  [string]$ConfigsPath = '.\configs',
  [string]$WallpaperPath = '.\wallpapers',
  [string]$LogDir = '.\logs',

  [switch]$SkipPackages,
  [switch]$SkipFonts,
  [switch]$SkipConfigs,
  [switch]$SkipWallpaper,
  [switch]$AllowUserScopeRetry,
  [switch]$Update
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

function Invoke-RelaunchAsAdmin {
  <#
.SYNOPSIS
  Relaunch this installer elevated.

.PARAMETER ScriptToRun
  Full path to this script.
#>
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$ScriptToRun)

  Write-Host '[*] Elevation required. Relaunching as Administrator...' -ForegroundColor Yellow
  $argsList = @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$ScriptToRun`"",
    '-Primary', $Primary, '-Fallback', $Fallback,
    '-RequiredPackagesPath', $RequiredPackagesPath,
    '-WindowsPackagesPath', $WindowsPackagesPath,
    '-FontsPath', $FontsPath,
    '-ConfigsPath', $ConfigsPath,
    '-WallpaperPath', $WallpaperPath,
    '-LogDir', $LogDir
  )
  if ($SkipPackages) { $argsList += '-SkipPackages' }
  if ($SkipFonts) { $argsList += '-SkipFonts' }
  if ($SkipConfigs) { $argsList += '-SkipConfigs' }
  if ($SkipWallpaper) { $argsList += '-SkipWallpaper' }
  if ($AllowUserScopeRetry) { $argsList += '-AllowUserScopeRetry' }
  if ($Update) { $argsList += '-Update' }

  Start-Process -FilePath "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" `
    -ArgumentList $argsList `
    -Verb RunAs `
    -WorkingDirectory (Split-Path -Parent $ScriptToRun) | Out-Null
  exit 0
}

# --- Resolve repo root & move there ---
$ScriptPath = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Path }
$RepoRoot = Split-Path -Parent $ScriptPath
Set-Location -Path $RepoRoot

# --- Transcript/logging ---
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }
$LogFile = Join-Path $LogDir ("install-{0}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
try { Start-Transcript -Path $LogFile -Append | Out-Null } catch { Write-Warning "Transcript unavailable: $($_.Exception.Message)" }

try {
  # --- Elevation check ---
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = [Security.Principal.WindowsPrincipal]::new($id)
  if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Invoke-RelaunchAsAdmin -ScriptToRun $ScriptPath
  }

  # --- Process-scoped execution policy & TLS defaults ---
  try { Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction Stop } catch { Write-Warning "Failed to set ExecutionPolicy (Process): $($_.Exception.Message)" }
  try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }

  # --- Load ONLY the core orchestrator ---
  $functionsDir = Join-Path $RepoRoot 'functions'
  $corePath = Join-Path $functionsDir 'core.ps1'
  if (-not (Test-Path $corePath)) { throw "Missing orchestrator: $corePath" }

  Write-Host "[+] Loading orchestrator (functions/core.ps1)" -ForegroundColor Cyan
  . $corePath   # must define Invoke-DotfilesSetup (and nothing else is loaded here)

  $entry = Get-Command -Name 'Invoke-DotfilesSetup' -ErrorAction SilentlyContinue
  if (-not $entry) { throw "Invoke-DotfilesSetup not found. Ensure functions/core.ps1 defines it." }

  # --- Hand off to core with all options ---
  Write-Host "[>] Handing off to core..." -ForegroundColor Green
  Invoke-DotfilesSetup `
    -RepoRoot            $RepoRoot `
    -Primary             $Primary `
    -Fallback            $Fallback `
    -RequiredPackagesPath $RequiredPackagesPath `
    -WindowsPackagesPath  $WindowsPackagesPath `
    -FontsPath           $FontsPath `
    -ConfigsPath         $ConfigsPath `
    -WallpaperPath       $WallpaperPath `
    -LogDir              $LogDir `
    -LogFile             $LogFile `
    -SkipPackages:$SkipPackages `
    -SkipFonts:$SkipFonts `
    -SkipConfigs:$SkipConfigs `
    -SkipWallpaper:$SkipWallpaper `
    -AllowUserScopeRetry:$AllowUserScopeRetry `
    -Update:$Update

  Write-Host "`n[OK] Windows Setup Completed Successfully" -ForegroundColor Green
  Write-Host ("Log saved to: {0}" -f $LogFile) -ForegroundColor Gray
}
catch {
  Write-Error $_
  Write-Host ("FAILED. Check log: {0}" -f $LogFile) -ForegroundColor Red
  exit 1
}
finally {
  try { Stop-Transcript | Out-Null } catch { }
}
