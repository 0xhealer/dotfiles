# functions/core.ps1

function Invoke-DotfilesSetup {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$RepoRoot,

    [ValidateSet('winget', 'choco', 'scoop')]
    [string]$Primary = 'winget',

    [ValidateSet('winget', 'choco', 'scoop')]
    [string]$Fallback = 'choco',

    [Parameter(Mandatory)][string]$RequiredPackagesPath,
    [Parameter(Mandatory)][string]$WindowsPackagesPath,

    [Parameter(Mandatory)][string]$FontsPath,
    [Parameter(Mandatory)][string]$ConfigsPath,
    [Parameter(Mandatory)][string]$WallpaperPath,

    [Parameter(Mandatory)][string]$LogDir,
    [Parameter(Mandatory)][string]$LogFile,

    [switch]$SkipPackages,
    [switch]$SkipFonts,
    [switch]$SkipConfigs,
    [switch]$SkipWallpaper,
    [switch]$AllowUserScopeRetry,
    [switch]$Update
  )

  Set-StrictMode -Version Latest
  $ErrorActionPreference = 'Continue'

  # --- Auto-import each function file except core.ps1 ---
  $functionsDir = Join-Path $RepoRoot 'functions'
  if (-not (Test-Path $functionsDir)) { throw "Functions directory not found at: $functionsDir" }

  Get-ChildItem -Path $functionsDir -Filter '*.ps1' -File |
  Where-Object { $_.Name -notmatch '^core\.ps1$' } |
  Sort-Object Name |
  ForEach-Object { . $_.FullName }

  # We now assume Write-Section exists.
  function Invoke-IfPresent {
    param([string]$Name, [hashtable]$Arguments = @{})
    $cmd = Get-Command -Name $Name -ErrorAction SilentlyContinue
    if ($cmd) { & $Name @Arguments }
  }

  Write-Section "Core Orchestration"
  Write-Host "[core] RepoRoot : $RepoRoot" -ForegroundColor DarkGray
  Write-Host "[core] LogFile  : $LogFile"  -ForegroundColor DarkGray

  Write-Section "Environment Checks"
  Invoke-IfPresent -Name 'Ensure-Winget'
  Invoke-IfPresent -Name 'Ensure-Choco'
  Invoke-IfPresent -Name 'Ensure-Scoop'

  Invoke-IfPresent -Name 'Initialize-CLIs'

  if (-not $SkipPackages) {
    Write-Section "Package Installation"

    $reqPath = (Resolve-Path $RequiredPackagesPath -ErrorAction Stop).Path
    $refPath = (Resolve-Path $WindowsPackagesPath -ErrorAction Stop).Path

    $installFn = Get-Command -Name 'Install-RequiredPackages' -ErrorAction SilentlyContinue
    if (-not $installFn) { throw "Install-RequiredPackages not found. Expect functions/Install-RequiredPackages.ps1" }

    Install-RequiredPackages `
      -RequiredPackagesPath $reqPath `
      -WindowsPackagesPath  $refPath `
      -Primary              $Primary `
      -Fallback             $Fallback `
      -AllowUserScopeRetry:$AllowUserScopeRetry
  }

  Invoke-IfPresent -Name 'Install-VSCodeExtensions'

  if (-not $SkipFonts) {
    Write-Section "Fonts"
    Invoke-IfPresent -Name 'Install-Fonts' -Arguments @{ FontsRoot = $FontsPath }
  }

  if (-not $SkipConfigs) {
    Write-Section "Configs"
    Invoke-IfPresent -Name 'Copy-Configs' -Arguments @{ ConfigsRoot = $ConfigsPath }
  }

  if (-not $SkipWallpaper) {
    Write-Section "Wallpaper"
    $auto = Get-Command -Name 'Set-WallpaperAuto' -ErrorAction SilentlyContinue
    $copy = Get-Command -Name 'Copy-Wallpaper'    -ErrorAction SilentlyContinue
    if ($auto) { Set-WallpaperAuto -Path $WallpaperPath }
    elseif ($copy) { Copy-Wallpaper -WallpaperRoot $WallpaperPath }
  }

  Write-Section "Completed"
  Write-Host "[OK] Core orchestration finished." -ForegroundColor Green
}
