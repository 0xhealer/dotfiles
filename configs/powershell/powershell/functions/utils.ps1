# Port of bash/functions/utils.bash

function mkcd {
    param([Parameter(Mandatory)][string]$Path)
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
    Set-Location $Path
}

function extract {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path $Path -PathType Leaf)) {
        Write-Host "'$Path' is not a valid file"
        return
    }

    # tar (bsdtar) ships natively on Windows 10 1803+ and handles most of
    # these directly, same as the bash version relying on GNU tar's
    # auto-detection. Expand-Archive covers .zip since tar's zip support
    # is inconsistent across bsdtar builds.
    switch -Regex ($Path) {
        '\.zip$'                    { Expand-Archive -Path $Path -DestinationPath . }
        '\.(tar\.gz|tgz)$'          { tar xzf $Path }
        '\.(tar\.bz2|tbz2)$'        { tar xjf $Path }
        '\.tar\.xz$'                { tar xJf $Path }
        '\.tar\.zst$'               { tar --zstd -xf $Path }
        '\.tar$'                    { tar xf $Path }
        '\.7z$'                     { 7z x $Path }
        '\.gz$'                     { tar xzf $Path }
        default                     { Write-Host "'$Path' cannot be extracted" }
    }
}

function hgrep {
    param([string]$Pattern)
    Get-History | Where-Object { $_.CommandLine -match $Pattern }
}

function dirsize {
    param([string]$Path = ".")
    $bytes = (Get-ChildItem $Path -Recurse -Force -ErrorAction SilentlyContinue |
        Measure-Object -Property Length -Sum).Sum
    "{0:N2} MB" -f ($bytes / 1MB)
}

function path {
    # Windows PATH is semicolon-delimited, not colon-delimited like Unix -
    # this is the one line in the whole port where the separator itself
    # had to change, not just the cmdlet.
    $env:PATH -split ';' | ForEach-Object -Begin { $i = 1 } -Process { "$i`t$_"; $i++ }
}

function backup {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path -PathType Leaf)) {
        Write-Host "File not found: $Path"
        return
    }
    $dest = "$Path.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Copy-Item -Path $Path -Destination $dest
    Write-Host "Backup created: $dest"
}
