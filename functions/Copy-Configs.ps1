# functions/Copy-Configs.ps1
<#
.SYNOPSIS
  Copies configuration files from your repo to their destinations with safe backups and zero prompts.

.DESCRIPTION
  Reads mappings from <ConfigsRoot>\mappings.json or mappings.jsonc (JSONC allowed).
  Each mapping object supports:
    - Source (relative to ConfigsRoot)
    - Destination (supports %ENVVARS%)
    - Type: "file" | "directory" (optional; inferred when omitted)
    - Exclude: array or single pattern (optional; for directories)
    - Backup: true|false (optional; default true)

  If no mappings file exists, mirrors the immediate children of <ConfigsRoot> into %USERPROFILE%
  (excluding the mapping files), with backups.

.NOTES
  - PowerShell 5.1 compatible (no ConvertFrom-Json -Depth, no dynamic keywords inside literals).
  - Robust against mappings parsed as Hashtable or PSCustomObject.
#>
function Copy-Configs {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$ConfigsRoot,
    [string]$BackupRoot,
    [switch]$DisableBackup
  )

  Set-StrictMode -Version Latest
  $ErrorActionPreference = 'Stop'

  if (-not (Test-Path -LiteralPath $ConfigsRoot -PathType Container)) {
    throw "ConfigsRoot not found or not a directory: $ConfigsRoot"
  }

  # ---------------- helpers ----------------
  function _Expand-Env([string]$p) {
    if ([string]::IsNullOrWhiteSpace($p)) { return $p }
    return [Environment]::ExpandEnvironmentVariables($p)
  }

  function _Ensure-Dir([string]$dir) {
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
      New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
  }

  # PS5.1-safe JSONC loader: strips comments + trailing commas, then ConvertFrom-Json (no -Depth)
  function _Read-JsonLoose([string]$path) {
    try {
      $raw = Get-Content -LiteralPath $path -Raw -Encoding UTF8

      # Strip /* ... */ block comments
      $raw = [regex]::Replace($raw, '/\*.*?\*/', '', 'Singleline')

      # Strip // line comments (approx)
      $raw = [regex]::Replace($raw, '(^|[^"\\])//.*$', '$1', 'Multiline')

      # Remove trailing commas before } or ]
      $raw = [regex]::Replace($raw, ',(\s*[}\]])', '$1')

      # Parse
      return ($raw | ConvertFrom-Json)
    }
    catch {
      throw "Failed to parse JSON: $path`n$($_.Exception.Message)`nHint: Escape backslashes in strings (use \\) or use forward slashes (/), and remove trailing commas."
    }
  }

  function _Is-Directory([string]$path) { Test-Path -LiteralPath $path -PathType Container }
  function _Is-File([string]$path) { Test-Path -LiteralPath $path -PathType Leaf }

  function _Relativize([string]$base, [string]$full) {
    $baseFx = (Resolve-Path $base).Path
    $fullFx = (Resolve-Path $full).Path
    if ($fullFx.StartsWith($baseFx, [StringComparison]::OrdinalIgnoreCase)) {
      return $fullFx.Substring($baseFx.Length).TrimStart('\', '/')
    }
    return (Split-Path -Leaf $fullFx)
  }

  # Safely read a property from either PSCustomObject or Hashtable
  function _GetProp($obj, [string]$name) {
    if ($null -eq $obj) { return $null }
    if ($obj -is [System.Collections.IDictionary]) {
      return $obj[$name]
    }
    else {
      $p = $obj.PSObject.Properties[$name]
      if ($p) { return $p.Value } else { return $null }
    }
  }

  function _ToArray($val) {
    if ($null -eq $val) { return @() }
    if ($val -is [System.Collections.IEnumerable] -and -not ($val -is [string])) { return @($val) }
    return @($val)
  }

  function _Backup-Item([string]$destPath, [string]$backupRoot) {
    if ($DisableBackup) { return }
    if (-not (Test-Path -LiteralPath $destPath)) { return }

    _Ensure-Dir $backupRoot

    $resolved = (Resolve-Path $destPath).Path
    $drive = ([IO.Path]::GetPathRoot($resolved)).TrimEnd('\')
    $rel = ($resolved -replace [regex]::Escape($drive), '').TrimStart('\')
    $backupTo = Join-Path $backupRoot $rel

    _Ensure-Dir (Split-Path -Parent $backupTo)
    Write-Host ("[backup] {0} -> {1}" -f $resolved, $backupTo) -ForegroundColor DarkGray
    try {
      Move-Item -LiteralPath $resolved -Destination $backupTo -Force
    }
    catch {
      # cross-volume/locked: copy then remove
      try {
        if (_Is-Directory $resolved) {
          Copy-Item -LiteralPath $resolved -Destination $backupTo -Recurse -Force
          Remove-Item -LiteralPath $resolved -Recurse -Force
        }
        else {
          _Ensure-Dir (Split-Path -Parent $backupTo)
          Copy-Item -LiteralPath $resolved -Destination $backupTo -Force
          Remove-Item -LiteralPath $resolved -Force
        }
      }
      catch {
        Write-Warning "Backup fallback failed for ${resolved}: $($_.Exception.Message)"
      }
    }
  }

  function _Copy-Directory([string]$src, [string]$dst, [string[]]$exclude) {
    _Ensure-Dir $dst

    $robo = Get-Command robocopy -ErrorAction SilentlyContinue
    if ($robo) {
      $args = @($src, $dst, '/E', '/NFL', '/NDL', '/NP', '/NJH', '/NJS', '/R:2', '/W:2')
      if ($exclude -and $exclude.Count -gt 0) {
        $xf = @(); $xd = @()
        foreach ($pattern in $exclude) {
          if ($pattern -match '\.' -or $pattern -like '*.*') { $xf += $pattern } else { $xd += $pattern }
        }
        if ($xf.Count -gt 0) { $args += @('/XF') + $xf }
        if ($xd.Count -gt 0) { $args += @('/XD') + $xd }
      }
      robocopy @args | Out-Null
      return
    }

    # Fallback to Copy-Item
    $items = Get-ChildItem -LiteralPath $src -Recurse -Force -File -ErrorAction SilentlyContinue
    foreach ($item in $items) {
      $leaf = $item.Name
      $skip = $false
      foreach ($pattern in $exclude) { if ($leaf -like $pattern) { $skip = $true; break } }
      if ($skip) { continue }

      $rel = _Relativize $src $item.FullName
      $target = Join-Path $dst $rel
      _Ensure-Dir (Split-Path -Parent $target)
      Copy-Item -LiteralPath $item.FullName -Destination $target -Force
    }
  }

  function _Copy-File([string]$src, [string]$dst) {
    _Ensure-Dir (Split-Path -Parent $dst)
    Copy-Item -LiteralPath $src -Destination $dst -Force
  }
  # -------------- end helpers --------------

  # Backups root (timestamped default)
  if ([string]::IsNullOrWhiteSpace($BackupRoot)) {
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $BackupRoot = Join-Path $env:USERPROFILE (Join-Path '.dotfiles-backup' $timestamp)
  }

  # Prefer mappings.json; otherwise mappings.jsonc; otherwise mirror
  $mapJson = Join-Path $ConfigsRoot 'mappings.json'
  $mapJsonc = Join-Path $ConfigsRoot 'mappings.jsonc'
  $mappingFile = $null
  if (Test-Path -LiteralPath $mapJson  -PathType Leaf) { $mappingFile = $mapJson }
  elseif (Test-Path -LiteralPath $mapJsonc -PathType Leaf) { $mappingFile = $mapJsonc }

  $plans = @()

  if ($mappingFile) {
    Write-Host ("[configs] Using mapping file: {0}" -f (Split-Path -Leaf $mappingFile)) -ForegroundColor DarkGray
    $json = _Read-JsonLoose $mappingFile
    if (-not ($json -is [System.Collections.IEnumerable])) {
      throw "Mapping file must be a JSON array: $mappingFile"
    }

    foreach ($m in $json) {
      $srcRel = _GetProp $m 'Source'
      $dstRaw = _GetProp $m 'Destination'
      if (-not $srcRel -or -not $dstRaw) {
        $bad = $m | ConvertTo-Json -Compress
        throw "Each mapping must include 'Source' and 'Destination'. Offending entry: $bad"
      }

      $src = Join-Path $ConfigsRoot $srcRel
      $dst = _Expand-Env $dstRaw

      # Type may be missing; infer safely without assuming PSCustomObject
      $typeRaw = _GetProp $m 'Type'
      $type = $null
      if ($typeRaw) {
        $type = $typeRaw.ToString().ToLowerInvariant()
      }
      else {
        if (_Is-Directory $src) { $type = 'directory' }
        elseif (_Is-File $src) { $type = 'file' }
        else { throw "Source not found: $src" }
      }

      $exclude = _ToArray (_GetProp $m 'Exclude')
      $backupFlag = _GetProp $m 'Backup'
      $doBackup = $true
      if ($null -ne $backupFlag) { $doBackup = [bool]$backupFlag }
      if ($DisableBackup) { $doBackup = $false }

      $plans += [pscustomobject]@{
        Source  = $src
        Dest    = $dst
        Type    = $type
        Exclude = $exclude
        Backup  = $doBackup
      }
    }
  }
  else {
    Write-Host "[configs] mappings.json/jsonc not found - mirroring into %USERPROFILE%." -ForegroundColor DarkGray
    $userProfilePath = $env:USERPROFILE   # do NOT assign to $home/$HOME
    Get-ChildItem -LiteralPath $ConfigsRoot -Force |
    # Exclude mapping files from being mirrored
    Where-Object { $_.Name -notin @('mappings.json', 'mappings.jsonc') } |
    ForEach-Object {
      $src = $_.FullName
      $rel = _Relativize $ConfigsRoot $src
      $dst = Join-Path $userProfilePath $rel
      $typeValue = if (_Is-Directory $src) { 'directory' } else { 'file' }
      $plans += [pscustomobject]@{
        Source  = $src
        Dest    = $dst
        Type    = $typeValue
        Exclude = @()
        Backup  = -not $DisableBackup
      }
    }
  }

  # Execute plans
  foreach ($p in $plans) {
    $src = $p.Source
    $dst = $p.Dest
    $typ = $p.Type
    $exc = @($p.Exclude)
    $doBackup = [bool]$p.Backup

    Write-Host ("[configs] {0} -> {1}" -f $src, $dst) -ForegroundColor Cyan

    if ($doBackup -and (Test-Path -LiteralPath $dst)) {
      _Backup-Item -destPath $dst -backupRoot $BackupRoot
    }

    if ($typ -eq 'directory') {
      if (-not (Test-Path -LiteralPath $src -PathType Container)) {
        Write-Warning "Source directory missing (skipping): $src"
        continue
      }
      _Copy-Directory -src $src -dst $dst -exclude $exc
    }
    elseif ($typ -eq 'file') {
      if (-not (Test-Path -LiteralPath $src -PathType Leaf)) {
        Write-Warning "Source file missing (skipping): $src"
        continue
      }
      _Copy-File -src $src -dst $dst
    }
    else {
      Write-Warning "Unknown Type '$typ' for Source: $src"
    }
  }

  if (-not $DisableBackup) {
    Write-Host ("[configs] Backups (if any) stored at: {0}" -f $BackupRoot) -ForegroundColor DarkGray
  }

  Write-Host "[configs] Config copy completed." -ForegroundColor Green
}
