$ErrorActionPreference = 'Stop'
. (Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'helper') 'helper.ps1')

Write-Step 'Wallpapers'

$files = @(Get-ChildItem -Path (Get-RepoPath 'assets/wallpapers') -File -ErrorAction SilentlyContinue)
if ($files.Count -eq 0) { throw 'no wallpapers in assets/wallpapers' }

$dest = Join-Path (Join-Path $HOME 'Pictures') 'Wallpapers'
Invoke-Dots -Description "mkdir $dest" -Action { New-Item -ItemType Directory -Force -Path $dest | Out-Null }
foreach ($file in $files) {
    $target = Join-Path $dest $file.Name
    if (-not (Test-Path $target)) {
        Invoke-Dots -Description "copy $($file.Name)" -Action { Copy-Item -LiteralPath $file.FullName -Destination $target }
    }
}
Write-Ok "$($files.Count) wallpapers available in $dest"
