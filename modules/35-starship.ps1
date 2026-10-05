$ErrorActionPreference = 'Stop'
. (Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'helper') 'helper.ps1')

Write-Step 'Starship'

if (-not (Test-DryRun) -and -not (Test-Command 'starship')) {
    Write-Warn 'starship is not on PATH yet; it is installed by the packages module (restart the terminal)'
}
Copy-Config -Source (Get-RepoPath 'configs/starship/starship.toml') -Destination (Join-Path (Join-Path $HOME '.config') 'starship.toml')
