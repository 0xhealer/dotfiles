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

# Windows PowerShell 5.1 turns a native command's stderr into a terminating error under
# $ErrorActionPreference = 'Stop' (code, gh and node all print warnings there). This runs it without that
# and returns the exit code.
function Invoke-Native {
    param([Parameter(Mandatory)][scriptblock]$Script)
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $script:NativeOutput = (& $Script 2>&1 | Out-String) } finally { $ErrorActionPreference = $previous }
    return $LASTEXITCODE
}

function Test-WingetPackage {
    param([Parameter(Mandatory)][string]$Id)
    $code = Invoke-Native { & winget list --id $Id --exact --accept-source-agreements }
    return ($code -eq 0 -and $script:NativeOutput -match [regex]::Escape($Id))
}

# winget sometimes cannot install PowerShell 7; fall back to the MSI from GitHub
function Install-PowerShell7Msi {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $release = Invoke-RestMethod -UseBasicParsing -Uri 'https://api.github.com/repos/PowerShell/PowerShell/releases/latest'
    $asset = $release.assets | Where-Object { $_.name -match 'win-x64\.msi$' } | Select-Object -First 1
    if (-not $asset) { throw 'no PowerShell 7 MSI found in the latest release' }
    $msi = Join-Path $env:TEMP $asset.name
    Invoke-WebRequest -UseBasicParsing -Uri $asset.browser_download_url -OutFile $msi
    $proc = Start-Process -FilePath msiexec.exe -Wait -PassThru -ArgumentList @('/i', "`"$msi`"", '/qn', 'ADD_PATH=1', 'REGISTER_MANIFEST=1', 'USE_MU=0', 'ENABLE_MU=0')
    Remove-Item -LiteralPath $msi -Force -ErrorAction SilentlyContinue
    if ($proc.ExitCode -ne 0 -and $proc.ExitCode -ne 3010) { throw "msiexec exited with $($proc.ExitCode)" }
}

function Install-WingetPackage {
    param([Parameter(Mandatory)][string]$Id)
    if ($script:DryRun) { Write-Host "    [dry-run] winget install --id $Id"; return $true }
    if (Test-WingetPackage -Id $Id) { Write-Info "already installed: $Id"; return $true }
    $winget = (Get-Command winget -ErrorAction Stop).Source
    $proc = Start-Process -FilePath $winget -NoNewWindow -PassThru -ArgumentList @(
        'install', '--id', $Id, '--exact', '--silent', '--disable-interactivity',
        '--accept-package-agreements', '--accept-source-agreements')
    # Cache the handle now, otherwise ExitCode is $null after the process exits.
    $null = $proc.Handle
    if (-not $proc.WaitForExit(20 * 60 * 1000)) {
        try { Stop-Process -Id $proc.Id -Force -ErrorAction Stop } catch { }
        Write-Warn "winget timed out for $Id after 20 minutes, continuing"
        return $false
    }
    $proc.WaitForExit()
    $proc.Refresh()
    $code = $proc.ExitCode
    # 0 ok, 3010 reboot required, 0x8A150061 already installed,
    # 0x8A15002B no applicable upgrade, 0x8A150109 restart needed to finish.
    $benign = @(0, 3010, -1978335135, -1978335189, -1978334967)
    if ($null -ne $code -and $benign -contains [int]$code) { Write-Ok "installed $Id"; return $true }
    # Unknown or missing exit code: trust the system, not the code.
    if (Test-WingetPackage -Id $Id) { Write-Ok "installed $Id"; return $true }
    $shown = if ($null -eq $code) { 'unknown' } else { '0x{0:X8}' -f [int]$code }
    Write-Warn "winget failed for $Id (exit $shown)"
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
