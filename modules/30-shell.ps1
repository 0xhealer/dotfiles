$ErrorActionPreference = 'Stop'
. (Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'helper') 'helper.ps1')

Write-Step 'PowerShell profile'

$documents = [Environment]::GetFolderPath('MyDocuments')
if (-not $documents) { $documents = Join-Path $HOME 'Documents' }
$profileDir = Join-Path $documents 'PowerShell'
$profilePath = Join-Path $profileDir 'Microsoft.PowerShell_profile.ps1'

Set-ConfigDir -Source (Get-RepoPath 'configs/powershell/powershell') -Destination (Join-Path (Join-Path $HOME '.config') 'powershell')
Copy-Config -Source (Get-RepoPath 'configs/powershell/Microsoft.PowerShell_profile.ps1') -Destination $profilePath

Write-Info 'open a new PowerShell 7 (pwsh) window to load the profile'
