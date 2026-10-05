if ($script:DotsHelperLoaded) { return }
$script:DotsHelperLoaded = $true

$ErrorActionPreference = 'Stop'

$script:DotsRoot = if ($env:DOTS_ROOT) { $env:DOTS_ROOT } else { Split-Path -Parent $PSScriptRoot }
$script:DryRun = ($env:DOTS_DRY_RUN -eq '1')
$script:BackupDir = if ($env:DOTS_BACKUP_DIR) { $env:DOTS_BACKUP_DIR } else {
    Join-Path (Join-Path $HOME '.dotfiles-backup') (Get-Date -Format 'yyyyMMdd-HHmmss')
}
$env:DOTS_ROOT = $script:DotsRoot
$env:DOTS_BACKUP_DIR = $script:BackupDir

function Write-Step { param([string]$Message) Write-Host ''; Write-Host "==> $Message" -ForegroundColor Cyan }
function Write-Info { param([string]$Message) Write-Host "  $Message" }
function Write-Ok { param([string]$Message) Write-Host "  [ok] $Message" -ForegroundColor Green }
function Write-Warn { param([string]$Message) Write-Host "  [!] $Message" -ForegroundColor Yellow }
function Write-Fail { param([string]$Message) Write-Host "  [x] $Message" -ForegroundColor Red }

function Test-IsWindowsHost {
    if (Get-Variable -Name IsWindows -ErrorAction SilentlyContinue) { return [bool]$IsWindows }
    return $true
}

function Test-DryRun { return $script:DryRun }

function Test-Command {
    param([Parameter(Mandatory)][string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Invoke-Dots {
    param(
        [Parameter(Mandatory)][string]$Description,
        [Parameter(Mandatory)][scriptblock]$Action
    )
    if ($script:DryRun) {
        Write-Host "    [dry-run] $Description"
        return
    }
    & $Action
}

function Update-SessionPath {
    if (-not (Test-IsWindowsHost)) { return }
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = (@($machine, $user) | Where-Object { $_ }) -join ';'
}

function Get-PackageList {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path)) { throw "package list not found: $Path" }
    Get-Content $Path | ForEach-Object { ($_ -replace '#.*$', '').Trim() } | Where-Object { $_ }
}

function Test-WingetPackage {
    param([Parameter(Mandatory)][string]$Id)
    $null = & winget list --id $Id --exact --accept-source-agreements 2>&1
    return ($LASTEXITCODE -eq 0)
}

function Install-WingetPackage {
    param([Parameter(Mandatory)][string]$Id)
    if ($script:DryRun) {
        Write-Host "    [dry-run] winget install --id $Id"
        return $true
    }
    if (Test-WingetPackage -Id $Id) {
        Write-Info "already installed: $Id"
        return $true
    }
    # Start-Process keeps winget on the real console. Piping it (| Out-Host) makes winget think its output is
    # redirected, so its spinner is printed on a new line for every frame instead of redrawing in place.
    $winget = (Get-Command winget -ErrorAction Stop).Source
    $proc = Start-Process -FilePath $winget -NoNewWindow -Wait -PassThru -ArgumentList @(
        'install', '--id', $Id, '--exact', '--silent', '--disable-interactivity',
        '--accept-package-agreements', '--accept-source-agreements')
    if ($proc.ExitCode -eq 0) {
        Write-Ok "installed $Id"
        return $true
    }
    Write-Warn "winget failed for $Id (exit $($proc.ExitCode))"
    return $false
}

function Backup-Item {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $full = (Resolve-Path -LiteralPath $Path).ProviderPath
    $home_ = $HOME.TrimEnd('\', '/')
    $rel = if ($full.StartsWith($home_, [StringComparison]::OrdinalIgnoreCase)) {
        $full.Substring($home_.Length).TrimStart('\', '/')
    } else {
        ($full -replace '^[A-Za-z]:', '').TrimStart('\', '/')
    }
    $dest = Join-Path $script:BackupDir $rel
    Invoke-Dots -Description "backup $Path -> $dest" -Action {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
        Move-Item -LiteralPath $Path -Destination $dest -Force
    }
    Write-Info "backed up $Path -> $dest"
}

function Set-ConfigDir {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination
    )
    if (-not (Test-Path -LiteralPath $Source)) { throw "missing source: $Source" }
    Invoke-Dots -Description "mkdir $(Split-Path -Parent $Destination)" -Action {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Destination) | Out-Null
    }
    Backup-Item -Path $Destination
    Invoke-Dots -Description "copy $Source -> $Destination" -Action {
        Copy-Item -LiteralPath $Source -Destination $Destination -Recurse -Force
    }
    Write-Ok "copied $Destination"
}

function Copy-Config {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination
    )
    if (-not (Test-Path -LiteralPath $Source)) { throw "missing source: $Source" }
    if ((Test-Path -LiteralPath $Destination -PathType Leaf) -and
        ((Get-FileHash -LiteralPath $Source).Hash -eq (Get-FileHash -LiteralPath $Destination).Hash)) {
        Write-Info "up to date: $Destination"
        return
    }
    Invoke-Dots -Description "mkdir $(Split-Path -Parent $Destination)" -Action {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Destination) | Out-Null
    }
    Backup-Item -Path $Destination
    Invoke-Dots -Description "copy $Source -> $Destination" -Action {
        Copy-Item -LiteralPath $Source -Destination $Destination -Force
    }
    Write-Ok "copied $Destination"
}

function Install-UserFont {
    param([Parameter(Mandatory)][string]$Path)
    $name = [IO.Path]::GetFileName($Path)
    $dir = Join-Path $env:LOCALAPPDATA 'Microsoft/Windows/Fonts'
    $target = Join-Path $dir $name
    $regPath = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    $kind = if ($name -like '*.otf') { 'OpenType' } else { 'TrueType' }
    $regName = ([IO.Path]::GetFileNameWithoutExtension($name)) + " ($kind)"
    if ((Test-Path $target) -and ((Get-FileHash $Path).Hash -eq (Get-FileHash $target).Hash)) { return $false }
    Invoke-Dots -Description "install font $name" -Action {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        Copy-Item -LiteralPath $Path -Destination $target -Force
        if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
        New-ItemProperty -Path $regPath -Name $regName -Value $target -PropertyType String -Force | Out-Null
    }
    return $true
}

function Get-RepoPath {
    param([Parameter(Mandatory)][string]$Relative)
    return (Join-Path $script:DotsRoot $Relative)
}
