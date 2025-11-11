# functions/Set-WallpaperAuto.ps1
<#
.SYNOPSIS
  Automatically selects and applies a wallpaper from a file or directory.

.DESCRIPTION
  - If wallpaper path is a file → sets it directly.
  - If it's a directory → selects the first *.jpg/*.png/*.jpeg/*.bmp file.
  - Silent, no prompts, safe to re-run.
  - Uses SystemParametersInfo → no UI flicker.

.PARAMETER Path
  File or directory path to the wallpaper.
#>
function Set-WallpaperAuto {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Path)

  Set-StrictMode -Version Latest
  $ErrorActionPreference = 'Stop'

  # Support both file and directory
  if (Test-Path -LiteralPath $Path -PathType Leaf) {
    $wall = Resolve-Path $Path
  }
  elseif (Test-Path -LiteralPath $Path -PathType Container) {
    $wall = Get-ChildItem -LiteralPath $Path -Include *.jpg, *.jpeg, *.png, *.bmp -File -ErrorAction SilentlyContinue |
    Select-Object -First 1

    if (-not $wall) {
      Write-Host "[wallpaper] No image files found in: $Path" -ForegroundColor DarkYellow
      return
    }
    $wall = $wall.FullName
  }
  else {
    Write-Host "[wallpaper] Path not found: $Path" -ForegroundColor Yellow
    return
  }

  # Register native SPI call once
  if (-not ("Win32Wallpaper" -as [type])) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32Wallpaper {
  [DllImport("user32.dll", SetLastError=true)]
  public static extern bool SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@
  }

  Set-ItemProperty 'HKCU:\Control Panel\Desktop' -Name Wallpaper -Value $wall
  [void][Win32Wallpaper]::SystemParametersInfo(0x14, 0, $wall, 0x01 -bor 0x02)

  Write-Host "[wallpaper] Applied: $wall" -ForegroundColor Green
}
