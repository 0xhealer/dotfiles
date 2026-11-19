$ErrorActionPreference = 'Stop'
. (Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'helper') 'helper.ps1')

# Visual Studio Build Tools with the "Desktop development with C++" workload: MSVC compiler and link.exe,
# the Windows SDK, CMake, Ninja and the VC runtime, plus the LLVM clang component. Rust (MSVC target),
# Python wheels and C/C++ all link through this; without it cargo fails with "link.exe not found".
# Runs before the package list so rustup finds a working toolchain on its first run.
Write-Step 'Visual Studio Build Tools (C++ workload)'

$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$components = @(
    'Microsoft.VisualStudio.Workload.VCTools',
    'Microsoft.VisualStudio.Component.VC.Llvm.Clang',
    'Microsoft.VisualStudio.Component.VC.Llvm.ClangToolset'
)
$addArgs = ($components | ForEach-Object { "--add $_" }) -join ' '

function Get-VcToolsPath {
    if (-not (Test-Path -LiteralPath $vswhere)) { return $null }
    $path = & $vswhere -products * -latest -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
    if ($path) { return ($path | Select-Object -First 1) }
    return $null
}

# any Build Tools instance, even one without the C++ workload (or a half-finished one)
function Get-BuildToolsInstance {
    if (-not (Test-Path -LiteralPath $vswhere)) { return $null }
    $path = & $vswhere -products * -all -property installationPath 2>$null
    if ($path) { return ($path | Select-Object -First 1) }
    return $null
}

function Get-DirMB($path) {
    if (-not (Test-Path -LiteralPath $path)) { return 0 }
    $sum = (Get-ChildItem -LiteralPath $path -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    if (-not $sum) { return 0 }
    return [int]($sum / 1MB)
}

# runs an installer and prints a progress line every 15 s (download size, installer processes, last log line);
# warns after 10 quiet minutes and gives up after 90
function Wait-Installer {
    param([Parameter(Mandatory)]$Process)
    $cache = Join-Path $env:ProgramData 'Microsoft\VisualStudio\Packages'
    $null = $Process.Handle
    $clock = [Diagnostics.Stopwatch]::StartNew()
    $quiet = [Diagnostics.Stopwatch]::StartNew()
    $lastMB = -1; $warned = $false
    while (-not $Process.WaitForExit(15000)) {
        $mb = Get-DirMB $cache
        $log = Get-ChildItem -Path $env:TEMP -Filter 'dd_*.log' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        $line = ''
        if ($log) { $line = [string](Get-Content -LiteralPath $log.FullName -Tail 1 -ErrorAction SilentlyContinue); if ($line.Length -gt 90) { $line = $line.Substring(0, 90) } }
        $n = @(Get-Process -Name 'setup', 'vs_installer', 'vs_installershell', 'vs_BuildTools', 'vs_setup_bootstrapper' -ErrorAction SilentlyContinue).Count
        Write-Info ('[{0:mm\:ss}] downloaded {1} MB, installer processes: {2}  {3}' -f $clock.Elapsed, $mb, $n, $line)
        if ($mb -ne $lastMB) { $lastMB = $mb; $quiet.Restart(); $warned = $false }
        elseif ($quiet.Elapsed.TotalMinutes -ge 10 -and -not $warned) {
            $warned = $true
            Write-Warn 'no download progress for 10 minutes: look for a hidden UAC prompt or installer window, or a pending reboot'
            if ($log) { Write-Warn "installer log: $($log.FullName)" }
        }
        if ($clock.Elapsed.TotalMinutes -ge 90) {
            try { Stop-Process -Id $Process.Id -Force -ErrorAction Stop } catch { }
            Write-Warn 'gave up after 90 minutes'
            return $null
        }
    }
    $Process.WaitForExit()
    return $Process.ExitCode
}

if (Test-DryRun) {
    Write-Host "    [dry-run] install or modify Visual Studio Build Tools: $addArgs --includeRecommended"
    return
}

$existing = Get-VcToolsPath
if ($existing) { Write-Ok "MSVC tools already installed: $existing"; return }

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { Write-Warn 'not running as administrator: a UAC prompt will appear (it may be behind this window); approve it or the install waits' }
$pending = (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') -or
           (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')
if ($pending) { Write-Warn 'Windows has a pending reboot; the Visual Studio installer may refuse to start until you restart' }

$opts = "--passive --wait --norestart $addArgs --includeRecommended"

# 1. Build Tools already registered (an earlier attempt, or a bare install): modify it with the Installer.
#    winget would answer "already installed" and ignore the workload.
$instance = Get-BuildToolsInstance
$setup = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\setup.exe'
if ($instance -and (Test-Path -LiteralPath $setup)) {
    Write-Info "Build Tools found at $instance without the C++ tools, adding the workload"
    $p = Start-Process -FilePath $setup -PassThru -ArgumentList "modify --installPath `"$instance`" $opts"
    $code = Wait-Installer -Process $p
    Write-Info "installer exit code: $code"
}

# 2. fresh install through winget
if (-not (Get-VcToolsPath)) {
    foreach ($id in 'Microsoft.VisualStudio.BuildTools', 'Microsoft.VisualStudio.2022.BuildTools') {
        Write-Info "installing $id with winget (several GB; progress is printed below)"
        $p = Start-Process -FilePath (Get-WingetExe) -NoNewWindow -PassThru -ArgumentList @(
            'install', '--id', $id, '--exact', '--source', 'winget', '--accept-package-agreements', '--accept-source-agreements',
            '--disable-interactivity', '--override', "`"$opts`"")
        $code = Wait-Installer -Process $p
        if (Get-VcToolsPath) { break }
        Write-Warn "$id did not install the C++ tools (exit $code)"
        $instance = Get-BuildToolsInstance
        if ($instance -and (Test-Path -LiteralPath $setup)) {
            Write-Info 'winget only registered Build Tools, adding the workload with the Visual Studio Installer'
            $p = Start-Process -FilePath $setup -PassThru -ArgumentList "modify --installPath `"$instance`" $opts"
            $null = Wait-Installer -Process $p
            if (Get-VcToolsPath) { break }
        }
    }
}

# 3. last resort: Microsoft's own bootstrapper, signature checked
if (-not (Get-VcToolsPath)) {
    Write-Warn "winget could not do it, using Microsoft's bootstrapper"
    $boot = Join-Path $env:TEMP 'vs_BuildTools.exe'
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -UseBasicParsing -Uri 'https://aka.ms/vs/stable/vs_BuildTools.exe' -OutFile $boot
        $sig = Get-AuthenticodeSignature -FilePath $boot
        if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch 'Microsoft') { throw "signature check failed ($($sig.Status))" }
        $p = Start-Process -FilePath $boot -PassThru -ArgumentList $opts
        $null = Wait-Installer -Process $p
    } catch {
        Write-Warn "bootstrapper failed: $($_.Exception.Message)"
    } finally {
        Remove-Item -LiteralPath $boot -Force -ErrorAction SilentlyContinue
    }
}

if (Get-VcToolsPath) {
    Write-Ok 'MSVC, clang (LLVM toolset), Windows SDK, CMake and Ninja installed (no reboot needed; log out and in if a tool is not found)'
} else {
    Write-Warn 'Build Tools install failed; open "Visual Studio Installer", Modify the Build Tools and tick "Desktop development with C++" and "C++ Clang tools for Windows", then rerun: .\install.cmd -Modules buildtools,devtools'
}
