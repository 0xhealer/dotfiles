$env:EDITOR = 'nvim'
$env:VISUAL = 'nvim'
$env:STARSHIP_CONFIG = Join-Path $HOME '.config\starship.toml'

$dotsPowerShell = Join-Path $HOME '.config\powershell'

if (Test-Path $dotsPowerShell) {
    Get-ChildItem -Path (Join-Path $dotsPowerShell 'functions') -Filter '*.ps1' -ErrorAction SilentlyContinue |
        Sort-Object Name | ForEach-Object { . $_.FullName }

    Get-ChildItem -Path $dotsPowerShell -Filter '*.ps1' -File |
        Sort-Object Name | ForEach-Object { . $_.FullName }
}

$localProfile = Join-Path (Split-Path $PROFILE -Parent) 'local.ps1'
if (Test-Path $localProfile) { . $localProfile }
