$ErrorActionPreference = 'Stop'
. (Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'helper') 'helper.ps1')

Write-Step 'Fastfetch'

$dest = Join-Path (Join-Path $HOME '.config') 'fastfetch'
if ((Test-Path $dest) -and ((Get-Item $dest -Force).LinkType)) { Backup-Item -Path $dest }
Invoke-Dots -Description "mkdir $dest" -Action { New-Item -ItemType Directory -Force -Path $dest | Out-Null }

Copy-Config -Source (Get-RepoPath 'configs/fastfetch/config.jsonc') -Destination (Join-Path $dest 'config.jsonc')
Set-ConfigDir -Source (Get-RepoPath 'configs/fastfetch/scripts') -Destination (Join-Path $dest 'scripts')
Set-ConfigDir -Source (Get-RepoPath 'assets/fastfetch-logos') -Destination (Join-Path $dest 'logos')
