# functions/Install-RequiredPackages.ps1
<#
.SYNOPSIS
  Installs packages listed in required-packages.json using windows-packages.json(c),
  with Winget as primary and Choco as fallback.

.DESCRIPTION
  Accepts:
    - windows-packages.json(c) as dictionary (preferred):
        {
          "Git": { "winget": "Git.Git", "choco": "git" },
          "ZenBrowser": { "winget": "Zen-Team.Zen-Browser", "choco": "na" }
        }

    - OR as array:
        [
          { "Name": "Git", "WingetId": "Git.Git", "ChocoId": "git" }
        ]

  Scoop is removed entirely.
#>
function Install-RequiredPackages {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$RequiredPackagesPath,
    [Parameter(Mandatory)][string]$WindowsPackagesPath,
    [ValidateSet('winget', 'choco')][string]$Primary = 'winget',
    [ValidateSet('winget', 'choco')][string]$Fallback = 'choco',
    [switch]$AllowUserScopeRetry
  )

  Set-StrictMode -Version Latest
  $ErrorActionPreference = 'Stop'

  # ----- Helpers -----
  function Read-JsonLoose {
    param([Parameter(Mandatory)]$Path)
    $raw = (Get-Content -LiteralPath $Path -Raw -Encoding UTF8)
    $raw = [regex]::Replace($raw, '/\*.*?\*/', '', 'Singleline')   # /* ... */
    $raw = [regex]::Replace($raw, '(^|[^:])//.*$', '$1', 'Multiline') # // ...
    return $raw | ConvertFrom-Json
  }

  function Is-MissingId([string]$v) {
    if (-not $v) { return $true }
    $v = $v.Trim()
    return ($v -eq '' -or $v -ieq 'na' -or $v -ieq 'none' -or $v -ieq 'n/a')
  }

  function Test-Exe([string]$cmd) { [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }

  function Test-InstalledByWinget([string]$id) {
    if (Is-MissingId $id -or -not (Test-Exe 'winget')) { return $false }
    $out = winget list --id $id --accept-source-agreements --accept-package-agreements 2>$null
    return ($LASTEXITCODE -eq 0 -and ($out | Select-String -SimpleMatch $id))
  }

  function Test-InstalledByChoco([string]$id) {
    if (Is-MissingId $id -or -not (Test-Exe 'choco')) { return $false }
    $out = choco list --local-only --exact $id 2>$null
    return [bool]($out | Where-Object { $_ -match "^\s*$([regex]::Escape($id))\s+" })
  }

  function Install-WithWinget([string]$id, [switch]$userRetry) {
    if (Is-MissingId $id) { return $false }
    $cmd = @('install', '--id', $id, '--exact', '--silent', '--accept-package-agreements', '--accept-source-agreements')
    winget @cmd
    if ($LASTEXITCODE -eq 0) { return $true }
    if ($userRetry) {
      winget @cmd --scope user
      if ($LASTEXITCODE -eq 0) { return $true }
    }
    return $false
  }

  function Install-WithChoco([string]$id) {
    if (Is-MissingId $id) { return $false }
    choco install $id -y --no-progress 2>$null
    return ($LASTEXITCODE -eq 0)
  }

  function Test-Installed($pkg) {
    if (Test-InstalledByWinget $pkg.winget) { return $true }
    if (Test-InstalledByChoco  $pkg.choco) { return $true }
    return $false
  }

  function Normalize-Record($item) {
    $w = $item.winget; if (-not $w) { $w = $item.WingetId }
    $c = $item.choco; if (-not $c) { $c = $item.ChocoId }
    return [pscustomobject]@{ winget = $w; choco = $c }
  }

  # ----- Load -----
  $required = Read-JsonLoose $RequiredPackagesPath
  $rawCatalog = Read-JsonLoose $WindowsPackagesPath
  $catalog = @{}

  if ($rawCatalog -is [System.Object[]]) {
    foreach ($item in $rawCatalog) {
      $catalog[$item.Name] = Normalize-Record $item
    }
  }
  else {
    foreach ($p in $rawCatalog.PSObject.Properties) {
      $catalog[$p.Name] = Normalize-Record $p.Value
    }
  }

  # Install loop
  foreach ($name in $required) {
    Write-Host "[pkg] $name" -ForegroundColor Cyan

    if (-not $catalog.ContainsKey($name)) {
      Write-Host "[skip] Not found in windows-packages.json(c): $name" -ForegroundColor DarkYellow
      continue
    }

    $rec = $catalog[$name]

    if (Test-Installed $rec) {
      Write-Host "[ok] Already installed: $name" -ForegroundColor Green
      continue
    }

    foreach ($mgr in @($Primary, $Fallback) | Select-Object -Unique) {
      $id = $rec.$mgr
      if (Is-MissingId $id) { continue }

      Write-Host "[>] ${mgr}: installing $name" -ForegroundColor White
      $ok = $false
      try {
        if ($mgr -eq 'winget') { $ok = Install-WithWinget $id -userRetry:$AllowUserScopeRetry }
        else { $ok = Install-WithChoco $id }
      }
      catch { $ok = $false }

      if ($ok) {
        Write-Host "[ok] Installed via ${mgr}: $name" -ForegroundColor Green
        break
      }
      else {
        Write-Host "[x] $mgr failed: $name" -ForegroundColor Red
      }
    }
  }
}
