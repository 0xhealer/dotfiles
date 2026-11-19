$ErrorActionPreference = 'Stop'
. (Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'helper') 'helper.ps1')

# Windows Security (Defender) scans every file a compiler writes and locks it for a moment, which breaks tools that build
# lots of small artifacts: tree-sitter parser builds ("lock file appears stale", "Failed to compile parser"), cargo, Mason.
# This excludes only the dev tool folders and build processes, not your whole disk. Skip with -Skip defender.
Write-Step 'Windows Security exclusions for dev tools'

$paths = @(
    (Join-Path $env:LOCALAPPDATA 'tree-sitter'),
    (Join-Path $env:LOCALAPPDATA 'nvim-data'),
    (Join-Path $env:LOCALAPPDATA 'nvim'),
    (Join-Path $env:USERPROFILE '.cargo'),
    (Join-Path $env:USERPROFILE '.rustup'),
    (Join-Path $env:USERPROFILE 'workspace')
) | Where-Object { $_ }
$procs = 'tree-sitter.exe', 'nvim.exe', 'clang.exe', 'clang++.exe', 'cl.exe', 'link.exe', 'lld-link.exe', 'cargo.exe', 'rustc.exe', 'go.exe'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warn 'not running as administrator; Windows Security exclusions skipped (run install.ps1 from an elevated terminal)'
    return
}

Invoke-Dots -Description 'add Windows Security exclusions for dev tool folders and build processes' -Action {
    try {
        foreach ($p in $paths) { Add-MpPreference -ExclusionPath $p -ErrorAction Stop }
        foreach ($n in $procs) { Add-MpPreference -ExclusionProcess $n -ErrorAction Stop }
    } catch {
        Write-Warn "could not add exclusions: $($_.Exception.Message)"
    }

    # Tamper Protection (or a managed device) makes Add-MpPreference succeed without doing anything, so verify
    $have = @((Get-MpPreference).ExclusionPath)
    $missing = @($paths | Where-Object { $have -notcontains $_ })
    if ($missing.Count -eq 0) {
        Write-Ok "Windows Security excludes $($paths.Count) dev folders and $($procs.Count) build processes"
    } else {
        Write-Warn 'Windows Security did not accept the exclusions (Tamper Protection or a managed device).'
        Write-Info 'Add them by hand: Windows Security > Virus & threat protection > Manage settings > Exclusions > Add folder:'
        $missing | ForEach-Object { Write-Info "  $_" }
    }
}

# A crashed or blocked tree-sitter build leaves a lock file behind and every later build then fails with
# "lock file ... appears stale"; remove them while nothing is building
$lockDir = Join-Path $env:LOCALAPPDATA 'tree-sitter\lock'
if ((Test-Path $lockDir) -and -not (Get-Process -Name 'nvim', 'tree-sitter' -ErrorAction SilentlyContinue)) {
    Invoke-Dots -Description "remove stale tree-sitter locks in $lockDir" -Action {
        Get-ChildItem $lockDir -Filter '*.lock' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        Write-Ok 'stale tree-sitter locks removed'
    }
}
