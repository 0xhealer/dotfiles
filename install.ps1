[CmdletBinding()]
param(
    [string[]]$Modules,
    [string[]]$Skip,
    [switch]$List,
    [switch]$DryRun,
    [switch]$NoElevate,
    [string]$OriginalProfile
)

$ErrorActionPreference = 'Stop'

if ($env:OS -eq 'Windows_NT' -and -not $List) {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($OriginalProfile -and $OriginalProfile -ne $env:USERPROFILE) {
        throw "elevated as a different account ($env:USERPROFILE instead of $OriginalProfile); run again with -NoElevate"
    }
    if (-not $isAdmin -and -not $NoElevate -and -not $DryRun) {
        $relaunch = @('-NoExit', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-OriginalProfile', "`"$env:USERPROFILE`"")
        if ($Modules) { $relaunch += @('-Modules', "`"$($Modules -join ',')`"") }
        if ($Skip) { $relaunch += @('-Skip', "`"$($Skip -join ',')`"") }
        Write-Host 'requesting administrator rights once so installers do not prompt one by one...'
        try {
            Start-Process -FilePath (Get-Process -Id $PID).Path -ArgumentList $relaunch -Verb RunAs
            return
        } catch {
            Write-Host 'elevation declined, continuing without administrator rights'
        }
    }
}

$DotsRoot = $PSScriptRoot
try { Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force } catch { }
try { Get-ChildItem -LiteralPath $DotsRoot -Recurse -File -Force -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue } catch { }
$env:DOTS_ROOT = $DotsRoot
if ($DryRun) { $env:DOTS_DRY_RUN = '1' } else { $env:DOTS_DRY_RUN = '0' }
$env:DOTS_BACKUP_DIR = Join-Path (Join-Path $HOME '.dotfiles-backup') (Get-Date -Format 'yyyyMMdd-HHmmss')

. (Join-Path (Join-Path $DotsRoot 'helper') 'helper.ps1')

$critical = @('prerequisites')

function Get-ModuleName {
    param([System.IO.FileInfo]$File)
    return ($File.BaseName -replace '^\d{2}-', '')
}

$files = @(Get-ChildItem -Path (Join-Path $DotsRoot 'modules') -Filter '*.ps1' | Where-Object { $_.Name -match '^\d{2}-' } | Sort-Object Name)
if ($files.Count -eq 0) { throw "no modules found in $(Join-Path $DotsRoot 'modules')" }
$known = @($files | ForEach-Object { Get-ModuleName $_ })

if ($List) {
    $known | ForEach-Object { Write-Host "  $_" }
    return
}

$only = @($Modules | ForEach-Object { $_ -split ',' } | Where-Object { $_ } | ForEach-Object { $_.Trim().ToLowerInvariant() })
$skipList = @($Skip | ForEach-Object { $_ -split ',' } | Where-Object { $_ } | ForEach-Object { $_.Trim().ToLowerInvariant() })

foreach ($name in $only) {
    if ($known -notcontains $name) { throw "unknown module '$name' (see .\install.ps1 -List)" }
}

Write-Step 'Platform'
Write-Info "powershell: $($PSVersionTable.PSVersion)"
Write-Info "backups:    $env:DOTS_BACKUP_DIR"
if ($DryRun) { Write-Warn 'dry-run: nothing will be changed' }

$transcriptStarted = $false
if (-not $DryRun) {
    $logDir = Join-Path (Join-Path (Join-Path $HOME '.local') 'state') 'dotfiles'
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $logFile = Join-Path $logDir ("install-{0}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    try {
        Start-Transcript -Path $logFile | Out-Null
        $transcriptStarted = $true
        Write-Info "log:        $logFile"
    } catch {
        Write-Warn "could not start transcript: $($_.Exception.Message)"
    }
}

$failed = @()
try {
    foreach ($file in $files) {
        $name = Get-ModuleName $file
        if ($only.Count -gt 0 -and $only -notcontains $name) { continue }
        if ($skipList -contains $name) {
            Write-Info "skipping $name"
            continue
        }

        try {
            & $file.FullName
        } catch {
            Write-Fail "module failed: $name - $($_.Exception.Message)"
            $failed += $name
            if ($critical -contains $name) { throw "critical module '$name' failed, aborting" }
        }
    }
} finally {
    if ($transcriptStarted) { Stop-Transcript | Out-Null }
}

Write-Step 'Summary'
if ($failed.Count -gt 0) {
    Write-Warn ("failed modules: " + ($failed -join ', '))
    exit 1
}
Write-Ok 'all modules completed'
Write-Info 'open a new terminal window to pick up PATH and profile changes'
