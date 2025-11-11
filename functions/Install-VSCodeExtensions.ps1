# functions/Install-VSCodeExtensions.ps1
<#
.SYNOPSIS
  Installs VS Code extensions silently and idempotently.

.DESCRIPTION
  - Reads extensions from .\configs\vscode\extensions.txt (TXT) or .json.
  - TXT: one extension per line; supports '#' and '//' comments and strips trailing commas/semicolons.
  - JSON: array of strings; each entry is trimmed and sanitized.
  - Skips already-installed extensions.
  - Installs into the current user's profile even when running elevated.

.PARAMETER ExtensionsPath
  Path to the list file. Default: .\configs\vscode\extensions.txt

.PARAMETER Edition
  'stable' | 'insiders' | 'both' (default: stable)
#>
function Install-VSCodeExtensions {
  [CmdletBinding()]
  param(
    [string]$ExtensionsPath = ".\configs\code\extensions.txt",
    [ValidateSet('stable', 'insiders', 'both')]
    [string]$Edition = 'stable'
  )

  Set-StrictMode -Version Latest
  $ErrorActionPreference = 'Stop'
  Write-Section "VS Code Extensions"

  function _resolveCodeCmd([string]$which) {
    $cmdName = if ($which -eq 'insiders') { 'code-insiders' } else { 'code' }
    $cmd = Get-Command $cmdName -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $candidates = if ($which -eq 'insiders') {
      @("$env:LOCALAPPDATA\Programs\Microsoft VS Code Insiders\bin\code-insiders.cmd",
        "$env:ProgramFiles\Microsoft VS Code Insiders\bin\code-insiders.cmd",
        "$env:ProgramFiles(x86)\Microsoft VS Code Insiders\bin\code-insiders.cmd")
    }
    else {
      @("$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd",
        "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd",
        "$env:ProgramFiles(x86)\Microsoft VS Code\bin\code.cmd")
    }
    foreach ($p in $candidates) { if (Test-Path -LiteralPath $p -PathType Leaf) { return $p } }
    return $null
  }

  function _sanitizeId([string]$s) {
    if ([string]::IsNullOrWhiteSpace($s)) { return $null }
    # Strip comments then trailing commas/semicolons
    $x = $s -replace '\s+#.*$', '' -replace '\s+//.*$', ''
    $x = $x.Trim() -replace '[,;]+$', ''
    $x = $x.Trim()
    if ($x -match '^[A-Za-z0-9-]+\.[A-Za-z0-9-]+$') { return $x }
    return $null
  }

  function _readList([string]$path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
      Write-Host "[vscode] Extensions list not found: $path (skipping)" -ForegroundColor DarkYellow
      return @()
    }
    $ext = [IO.Path]::GetExtension($path).ToLowerInvariant()
    if ($ext -eq '.json') {
      $arr = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
      return @($arr | ForEach-Object { _sanitizeId ($_.ToString()) } | Where-Object { $_ })
    }
    $out = @()
    foreach ($line in (Get-Content -LiteralPath $path -Encoding UTF8)) {
      $id = _sanitizeId $line
      if ($id) { $out += $id }
    }
    $out
  }

  # Targets to process
  $targets = switch ($Edition) {
    'stable' { @('stable') }
    'insiders' { @('insiders') }
    'both' { @('stable', 'insiders') }
  }

  # Resolve code commands
  $codeCmds = @{}
  foreach ($t in $targets) {
    $cmd = _resolveCodeCmd $t
    if ($cmd) { $codeCmds[$t] = $cmd } else { Write-Host "[vscode] $t CLI not found; skipping." -ForegroundColor DarkGray }
  }
  if ($codeCmds.Count -eq 0) { Write-Host "[vscode] No VS Code CLI detected." -ForegroundColor Yellow; return }

  # Read desired list
  $list = _readList $ExtensionsPath
  if (-not $list -or $list.Count -eq 0) {
    Write-Host "[vscode] No extensions to install." -ForegroundColor DarkGray
    return
  }

  # Force installs into the user context (even when elevated)
  $userDataDir = Join-Path $env:APPDATA 'Code'                    # %APPDATA%\Code
  $extDir = Join-Path $env:USERPROFILE '.vscode\extensions'  # %USERPROFILE%\.vscode\extensions
  foreach ($d in @($userDataDir, $extDir)) {
    if (-not (Test-Path -LiteralPath $d -PathType Container)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
  }

  foreach ($pair in $codeCmds.GetEnumerator()) {
    $which = $pair.Key
    $cmd = $pair.Value
    Write-Host "[vscode] Target: $which ($cmd)" -ForegroundColor Cyan

    # Warm up CLI (builds caches)
    try { & $cmd --version | Out-Null } catch {}

    # Discover installed extensions
    $installed = @()
    try { $installed = & $cmd --list-extensions 2>$null } catch { $installed = @() }
    $installedSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($e in $installed) { [void]$installedSet.Add($e.Trim()) }

    $ok = 0; $skip = 0; $fail = 0

    foreach ($ext in $list) {
      if ($installedSet.Contains($ext)) {
        Write-Host "[skip] $ext already installed" -ForegroundColor DarkGray
        $skip++; continue
      }

      Write-Host "[>] Installing $ext" -ForegroundColor White
      $args = @('--install-extension', $ext, '--force', '--extensions-dir', $extDir, '--user-data-dir', $userDataDir)
      & $cmd @args
      $success = ($LASTEXITCODE -eq 0)
      if (-not $success) {
        Start-Sleep -Seconds 2
        & $cmd @args
        $success = ($LASTEXITCODE -eq 0)
      }

      if ($success) {
        Write-Host "[ok] $ext" -ForegroundColor Green
        $ok++; [void]$installedSet.Add($ext)
      }
      else {
        Write-Host "[x] Failed: $ext" -ForegroundColor Red
        $fail++
      }
    }

    Write-Host ("[vscode] {0}: Installed={1} Skipped={2} Failed={3}" -f $which, $ok, $skip, $fail) -ForegroundColor Cyan
  }
}
