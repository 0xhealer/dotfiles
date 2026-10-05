$ErrorActionPreference = 'Stop'
. (Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'helper') 'helper.ps1')

Write-Step 'Packages (winget)'

$ids = @(Get-PackageList -Path (Get-RepoPath 'packages/windows.txt'))
$failed = @()
foreach ($id in $ids) {
    if (-not (Install-WingetPackage -Id $id)) { $failed += $id }
}
Update-SessionPath

$pwshPath = Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe'
if (-not (Test-DryRun) -and -not (Test-Path -LiteralPath $pwshPath)) {
    Write-Warn 'PowerShell 7 is still missing, installing the MSI directly'
    try {
        Install-PowerShell7Msi
        Update-SessionPath
        if (Test-Path -LiteralPath $pwshPath) { Write-Ok 'installed PowerShell 7' } else { Write-Warn 'PowerShell 7 MSI ran but pwsh.exe was not found' }
    } catch {
        Write-Warn "could not install PowerShell 7: $($_.Exception.Message)"
    }
}

if ($failed.Count -gt 0) {
    Write-Warn ("packages that failed: " + ($failed -join ', '))
} else {
    Write-Ok "$($ids.Count) packages present"
}
