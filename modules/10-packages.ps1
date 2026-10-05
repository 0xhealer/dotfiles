$ErrorActionPreference = 'Stop'
. (Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'helper') 'helper.ps1')

Write-Step 'Packages (winget)'

$ids = @(Get-PackageList -Path (Get-RepoPath 'packages/windows.txt'))
$failed = @()
foreach ($id in $ids) {
    if (-not (Install-WingetPackage -Id $id)) { $failed += $id }
}
Update-SessionPath

if ($failed.Count -gt 0) {
    Write-Warn ("packages that failed: " + ($failed -join ', '))
} else {
    Write-Ok "$($ids.Count) packages present"
}
