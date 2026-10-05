$ErrorActionPreference = 'Stop'
. (Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'helper') 'helper.ps1')

Write-Step 'Prerequisites'

if (-not (Test-IsWindowsHost)) { throw 'install.ps1 supports Windows only. Use install.sh on Linux.' }

if (-not (Test-DryRun)) {
    if (-not (Test-Command 'winget')) {
        throw 'winget not found. Install "App Installer" from the Microsoft Store, then run again.'
    }
    $userPolicy = [string](Get-ExecutionPolicy -Scope CurrentUser)
    if ($userPolicy -in @('Undefined', 'Restricted', 'AllSigned')) {
        try {
            Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force -ErrorAction Stop
        } catch {
            Write-Info 'execution policy is managed by your system, leaving it as is'
        }
    }
}

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Warn 'running under Windows PowerShell 5.1; PowerShell 7 is installed by the packages module'
}

foreach ($dir in @((Join-Path $HOME '.config'), (Join-Path $HOME 'Pictures'), (Join-Path (Join-Path $HOME 'workspace') 'github'))) {
    Invoke-Dots -Description "mkdir $dir" -Action { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
}

Write-Ok 'prerequisites ready'
