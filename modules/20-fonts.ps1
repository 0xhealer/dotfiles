$ErrorActionPreference = 'Stop'
. (Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'helper') 'helper.ps1')

Write-Step 'Fonts'

$fonts = @(Get-ChildItem -Path (Get-RepoPath 'assets/fonts') -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in '.ttf', '.otf' })
if ($fonts.Count -eq 0) { throw 'no fonts found in assets/fonts' }

$installed = 0
foreach ($font in $fonts) {
    if (Install-UserFont -Path $font.FullName) { $installed++ }
}
Write-Ok "$installed new font files installed, $($fonts.Count - $installed) already present"
