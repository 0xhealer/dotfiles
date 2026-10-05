function Assert-GhReady {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Host 'gh is not installed'
        return $false
    }
    & gh auth status *> $null
    if ($LASTEXITCODE -ne 0) {
        & gh auth login
        if ($LASTEXITCODE -ne 0) { return $false }
    }
    return $true
}

function Get-GhBaseDir {
    if ($env:GH_CLONE_DIR) { return $env:GH_CLONE_DIR }
    return (Join-Path (Join-Path $HOME 'workspace') 'github')
}

function ghclone {
    param(
        [Parameter(Mandatory, Position = 0)][string]$Repo,
        [Parameter(Position = 1)][string]$Dir
    )
    if (-not (Assert-GhReady)) { return }
    if ($Repo -notmatch '/') {
        $Repo = "$((& gh api user --jq .login).Trim())/$Repo"
    }
    $name = ($Repo -split '/')[-1] -replace '\.git$', ''
    if (-not $Dir) { $Dir = Join-Path (Get-GhBaseDir) $name }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Dir) | Out-Null
    if (Test-Path (Join-Path $Dir '.git')) {
        Write-Host "already cloned: $Dir"
    } else {
        & gh repo clone $Repo $Dir
        if ($LASTEXITCODE -ne 0) { return }
    }
    Set-Location $Dir
}

function ghcreate {
    param(
        [Parameter(Position = 0)][string]$Name,
        [Alias('p')][switch]$Public,
        [Alias('d')][string]$Description
    )
    if (-not (Assert-GhReady)) { return }
    if (-not $Name) {
        $top = (& git rev-parse --show-toplevel 2>$null)
        if (-not $top) {
            Write-Host 'not in a git repo; pass a name to create a new one'
            return
        }
        & git remote get-url origin *> $null
        if ($LASTEXITCODE -eq 0) {
            Write-Host 'origin is already set'
            return
        }
        & git rev-parse --verify -q HEAD *> $null
        if ($LASTEXITCODE -ne 0) {
            Write-Host 'make a commit first'
            return
        }
        Set-Location $top
        $Name = Split-Path -Leaf $top
    } else {
        $dest = Join-Path (Get-GhBaseDir) $Name
        if (Test-Path $dest) {
            Write-Host "already exists: $dest"
            return
        }
        New-Item -ItemType Directory -Force -Path $dest | Out-Null
        Set-Location $dest
        & git init -q -b main
        Set-Content -Path README.md -Value "# $Name"
        & git add README.md
        & git commit -q -m 'Initial commit'
        if ($LASTEXITCODE -ne 0) { return }
    }
    $visibility = if ($Public) { '--public' } else { '--private' }
    $ghArgs = @('repo', 'create', $Name, $visibility, '--source=.', '--remote=origin', '--push')
    if ($Description) { $ghArgs += @('--description', $Description) }
    & gh @ghArgs
}
