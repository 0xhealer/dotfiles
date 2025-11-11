# functions/Install-Fonts.ps1
<#
.SYNOPSIS
  Silently installs fonts (TTF/OTF/TTC) without user interaction.

.DESCRIPTION
  - Recursively scans the provided FontsRoot directory.
  - Skips fonts already installed (based on actual font file presence in C:\Windows\Fonts).
  - Installs fonts *without* Shell.CopyHere, avoiding all UI prompts.
  - Writes registry entries automatically.
#>

function Install-Fonts {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][string]$FontsRoot
  )

  Set-StrictMode -Version Latest
  $ErrorActionPreference = 'Stop'

  if (-not (Test-Path $FontsRoot)) {
    Write-Host "[fonts] Folder not found: $FontsRoot" -ForegroundColor DarkYellow
    return
  }

  $fontFiles = Get-ChildItem $FontsRoot -Recurse -Include *.ttf, *.otf, *.ttc -File 2>$null
  if (-not $fontFiles) {
    Write-Host "[fonts] No fonts found in $FontsRoot" -ForegroundColor Yellow
    return
  }

  $fontsDir = "$env:WINDIR\Fonts"
  $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"

  $installed = 0
  $skipped = 0

  foreach ($fontFile in $fontFiles) {

    $destPath = Join-Path $fontsDir $fontFile.Name

    # Skip if already installed
    if (Test-Path $destPath) {
      Write-Host "[skip] $($fontFile.Name) already installed." -ForegroundColor DarkGray
      $skipped++
      continue
    }

    try {
      Copy-Item -LiteralPath $fontFile.FullName -Destination $fontsDir -Force

      # Register the font — Use filename as key; Windows figures out display name
      $regName = $fontFile.BaseName
      New-ItemProperty -Path $regPath -Name $regName -Value $fontFile.Name -PropertyType String -Force | Out-Null

      $installed++
      Write-Host "[ok] Installed $($fontFile.Name)" -ForegroundColor Green
    }
    catch {
      Write-Host "[fail] Could not install $($fontFile.Name): $($_.Exception.Message)" -ForegroundColor Red
    }
  }

  # Tell Windows to reload fonts
  $HWND_BROADCAST = 0xffff
  $WM_FONTCHANGE = 0x001D
  Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class NativeFont {
  [DllImport("user32.dll", SetLastError=true)]
  public static extern IntPtr SendMessageTimeout(IntPtr hWnd, int Msg, IntPtr wParam, IntPtr lParam, int fuFlags, int uTimeout, out IntPtr lpdwResult);
}
"@
  [IntPtr]$result = [IntPtr]::Zero
  [void][NativeFont]::SendMessageTimeout($HWND_BROADCAST, $WM_FONTCHANGE, [IntPtr]::Zero, [IntPtr]::Zero, 2, 5000, [ref]$result)

  Write-Host ""
  Write-Host "[fonts] Installed: $installed" -ForegroundColor Green
  Write-Host "[fonts] Skipped  : $skipped"   -ForegroundColor Yellow
  Write-Host ""
}
