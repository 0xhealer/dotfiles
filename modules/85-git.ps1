$ErrorActionPreference = 'Stop'
. (Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'helper') 'helper.ps1')

Write-Step 'Git'

Update-SessionPath
$name = $env:GIT_NAME
$email = $env:GIT_EMAIL
if (-not (Test-DryRun) -and (Test-Command 'git')) {
    if (-not $name) { $name = (& git config --global user.name 2>$null) }
    if (-not $email) { $email = (& git config --global user.email 2>$null) }
}

$localConfig = Join-Path $HOME '.gitconfig.local'
if ($name -and $email -and -not (Test-Path $localConfig) -and -not (Test-DryRun)) {
    "[user]`n    name = $name`n    email = $email`n" | Set-Content -Path $localConfig -Encoding ASCII
    Write-Ok "identity saved to $localConfig"
} elseif (-not (Test-Path $localConfig)) {
    Write-Warn "no git identity found; set GIT_NAME/GIT_EMAIL or edit $localConfig"
}

Copy-Config -Source (Get-RepoPath 'configs/git/gitconfig') -Destination (Join-Path $HOME '.gitconfig')

if (-not (Test-DryRun) -and (Test-Command 'git')) {
    & git config --global core.autocrlf true
}

if (-not (Test-DryRun) -and (Test-Command 'gh')) {
    & gh auth status *> $null
    if ($LASTEXITCODE -ne 0) { Write-Info "run 'gh auth login' once; ghclone and ghcreate use it" }
}
