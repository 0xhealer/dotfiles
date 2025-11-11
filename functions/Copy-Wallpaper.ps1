# functions/Copy-Wallpaper.ps1
<#
.SYNOPSIS
  Copies wallpaper(s) into Pictures\Wallpapers and applies the first one.

.DESCRIPTION
  - Copies all supported images (.jpg/.png/.jpeg/.bmp) to:
      %USERPROFILE%\Pictures\Wallpapers
  - Automatically applies the first wallpaper copied.
  - Safe to re-run; existing wallpapers are preserved unless overwritten.

.PARAMETER WallpaperRoot
  Directory containing wallpapers.
#>
function Copy-Wallpaper {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$WallpaperRoot)

  Set-StrictMode -Version Latest
  $ErrorActionPreference = 'Stop'

  if (-not (Test-Path -LiteralPath $WallpaperRoot -PathType Container)) {
    Write-Host "[wallpaper] No wallpaper directory found: $WallpaperRoot" -ForegroundColor Yellow
    return
  }

  $destDir = Join-Path $env:USERPROFILE "Pictures\Wallpapers"
  if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir | Out-Null }

  $files = Get-ChildItem -LiteralPath $WallpaperRoot -Include *.jpg, *.jpeg, *.png, *.bmp -File -ErrorAction SilentlyContinue
  if (-not $files) {
    Write-Host "[wallpaper] No images found in $WallpaperRoot" -ForegroundColor DarkGray
    return
  }

  foreach ($file in $files) {
    Copy-Item $file.FullName -Destination (Join-Path $destDir $file.Name) -Force
  }

  # Apply first copied wallpaper
  $first = Join-Path $destDir $files[0].Name
  Set-WallpaperAuto -Path $first
}
