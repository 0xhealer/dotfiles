$ErrorActionPreference = 'Stop'
. (Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'helper') 'helper.ps1')

Write-Step 'Windows Terminal'

$source = Get-RepoPath 'configs/windows-terminal/settings.json'
$packages = Join-Path $env:LOCALAPPDATA 'Packages'
$candidates = @(
    @{ Root = (Join-Path $packages 'Microsoft.WindowsTerminal_8wekyb3d8bbwe'); Dir = (Join-Path (Join-Path $packages 'Microsoft.WindowsTerminal_8wekyb3d8bbwe') 'LocalState') },
    @{ Root = (Join-Path $packages 'Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe'); Dir = (Join-Path (Join-Path $packages 'Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe') 'LocalState') },
    @{ Root = (Join-Path (Join-Path $env:LOCALAPPDATA 'Microsoft') 'Windows Terminal'); Dir = (Join-Path (Join-Path $env:LOCALAPPDATA 'Microsoft') 'Windows Terminal') }
)

$applied = 0
foreach ($candidate in $candidates) {
    if (Test-Path $candidate.Root -PathType Container) {
        Copy-Config -Source $source -Destination (Join-Path $candidate.Dir 'settings.json')
        $applied++
    }
}

if ($applied -eq 0) {
    Write-Warn 'Windows Terminal data folder not found; start Windows Terminal once, then run: .\install.ps1 -Modules terminal'
}
