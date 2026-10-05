[CmdletBinding()]
param(
    [string[]]$Modules,
    [string[]]$Skip,
    [switch]$List,
    [switch]$DryRun,
    [switch]$NoElevate
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$repo = if ($env:DOTS_REPO) { $env:DOTS_REPO } else { '0xhealer/dotfiles' }
$branch = if ($env:DOTS_BRANCH) { $env:DOTS_BRANCH } else { 'main' }
$dest = if ($env:DOTS_DIR) { $env:DOTS_DIR } else { Join-Path $HOME 'dotfiles' }

try { Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force } catch { }

if (Get-Command git -ErrorAction SilentlyContinue) {
    if (Test-Path (Join-Path $dest '.git')) {
        Write-Host "==> updating $dest"
        git -C $dest pull --ff-only
    } else {
        Write-Host "==> cloning $repo into $dest"
        git clone --depth 1 --branch $branch "https://github.com/$repo" $dest
    }
    if ($LASTEXITCODE -ne 0) { throw 'git failed' }
} else {
    Write-Host "==> git not found, downloading $repo ($branch) into $dest"
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ("dots-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    $zip = Join-Path $tmp 'dotfiles.zip'
    Invoke-WebRequest -UseBasicParsing -Uri "https://codeload.github.com/$repo/zip/refs/heads/$branch" -OutFile $zip
    Expand-Archive -Path $zip -DestinationPath $tmp -Force
    $src = Get-ChildItem -Path $tmp -Directory | Select-Object -First 1
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Copy-Item -Path (Join-Path $src.FullName '*') -Destination $dest -Recurse -Force
    Remove-Item -Recurse -Force $tmp
}

Get-ChildItem -LiteralPath $dest -Recurse -File -Force -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue

$installArgs = @()
if ($Modules) { $installArgs += @('-Modules', ($Modules -join ',')) }
if ($Skip) { $installArgs += @('-Skip', ($Skip -join ',')) }
if ($List) { $installArgs += '-List' }
if ($DryRun) { $installArgs += '-DryRun' }
if ($NoElevate) { $installArgs += '-NoElevate' }

Write-Host "==> running install.cmd $($installArgs -join ' ')"
& (Join-Path $dest 'install.cmd') @installArgs
