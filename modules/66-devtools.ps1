$ErrorActionPreference = 'Stop'
. (Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'helper') 'helper.ps1')

# Language toolchains: Rust, Go, Python, C/C++ and web (Node). Makes sure each one is usable from a fresh
# terminal and that the pieces Neovim and VS Code expect (rust-analyzer, clippy, gopls, ...) are in place.
Write-Step 'Language toolchains (Rust, Go, Python, C, Web)'

Update-SessionPath

# Directories that must be on the user PATH: cargo, go, npm globals, the clang that ships with the Build Tools,
# and the install dirs of Go, Node and Python in case their installers did not add themselves
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$vsRoot = $null
if (Test-Path -LiteralPath $vswhere) {
    $vsRoot = & $vswhere -products * -latest -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null | Select-Object -First 1
}
$userBins = @(
    (Join-Path $HOME '.cargo\bin'),
    (Join-Path $HOME 'go\bin'),
    (Join-Path $env:APPDATA 'npm'),
    (Join-Path $env:ProgramFiles 'Go\bin'),
    (Join-Path $env:ProgramFiles 'nodejs')
)
if ($vsRoot) { $userBins += (Join-Path $vsRoot 'VC\Tools\Llvm\x64\bin') }
foreach ($py in (Get-ChildItem -Path (Join-Path $env:LOCALAPPDATA 'Programs\Python') -Directory -Filter 'Python3*' -ErrorAction SilentlyContinue)) {
    $userBins += $py.FullName
    $userBins += (Join-Path $py.FullName 'Scripts')
}
$userBins = @($userBins | Where-Object { Test-Path -LiteralPath $_ -PathType Container } | Select-Object -Unique)
# cargo and go bins may not exist before the first build; they are still added
$userBins += @((Join-Path $HOME '.cargo\bin'), (Join-Path $HOME 'go\bin'), (Join-Path $env:APPDATA 'npm') | Where-Object { $userBins -notcontains $_ })
if (-not (Test-DryRun)) {
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $parts = @($userPath -split ';' | Where-Object { $_ })
    $changed = $false
    foreach ($bin in $userBins) {
        if ($parts -notcontains $bin -and "$machinePath;" -notlike "*$bin;*" -and "$machinePath;" -notlike "*$bin\;*") {
            $parts += $bin; $changed = $true; Write-Info "added $bin to the user PATH"
        }
    }
    if ($changed) { [Environment]::SetEnvironmentVariable('Path', ($parts -join ';'), 'User') }
    foreach ($bin in $userBins) { if (($env:Path -split ';') -notcontains $bin) { $env:Path += ";$bin" } }
}

# --- Rust: MSVC toolchain + the components rust-analyzer, clippy and rustfmt
if (Test-DryRun) {
    Write-Host '    [dry-run] rustup default stable-x86_64-pc-windows-msvc; rustup component add rust-analyzer clippy rustfmt'
} elseif (Test-Command 'rustup') {
    $code = Invoke-Native { & rustup default stable-x86_64-pc-windows-msvc }
    if ($code -ne 0) { Write-Warn "rustup default failed: $($script:NativeOutput.Trim())" }
    foreach ($component in 'rust-analyzer', 'clippy', 'rustfmt') {
        $code = Invoke-Native { & rustup component add $component }
        if ($code -ne 0) { Write-Warn "rustup component $component failed" }
    }
    Write-Ok 'Rust: stable MSVC toolchain with rust-analyzer, clippy, rustfmt'
} else {
    Write-Warn 'rustup not on PATH yet; restart the terminal and run: .\install.ps1 -Modules devtools'
}

# --- the linker check that rustc itself performs
if (-not (Test-DryRun)) {
    if ($vsRoot) {
        Write-Ok 'MSVC linker available (rustc finds link.exe through vswhere, no Developer Prompt needed)'
    } else {
        Write-Warn 'MSVC tools missing: cargo will fail with "link.exe not found". Run: .\install.ps1 -Modules buildtools'
    }
    # Git for Windows ships a coreutils link.exe that shadows the MSVC linker if its usr\bin is on PATH
    $gitLink = Get-Command link.exe -ErrorAction SilentlyContinue
    if ($gitLink -and $gitLink.Source -match '\\Git\\usr\\bin\\') {
        Write-Warn "Git's link.exe ($($gitLink.Source)) comes first on PATH and breaks Rust builds; remove Git\usr\bin from PATH"
    }
}

# --- Go: gopls and friends are installed by Neovim/VS Code, only check the toolchain
if (-not (Test-DryRun)) {
    if (Test-Command 'go') { Write-Ok "Go: $(& go version)" } else { Write-Warn 'go not on PATH yet; restart the terminal' }
}

# --- Python: make sure pip and a venv-capable interpreter exist
if (-not (Test-DryRun)) {
    if (Test-Command 'python') {
        $code = Invoke-Native { & python -m pip --version }
        if ($code -eq 0) { Write-Ok "Python: $($script:NativeOutput.Trim())" } else { Write-Warn 'python has no pip' }
    } else {
        Write-Warn 'python not on PATH yet; restart the terminal'
    }
}

# --- C / C++ : clang/clang-cl/lld come from the Build Tools' LLVM toolset; clangd and clang-format are installed by Mason
if (-not (Test-DryRun)) {
    if (Test-Command 'clang') { Write-Ok 'C/C++: clang found' } else { Write-Warn 'clang not on PATH yet; restart the terminal (Build Tools LLVM component)' }
}

# --- Web: node + npm (the TypeScript server is bundled with vtsls, nothing to install globally)
if (-not (Test-DryRun)) {
    if (Test-Command 'node') { Write-Ok "Web: node $(& node --version)" } else { Write-Warn 'node not on PATH yet; restart the terminal' }
}

Write-Info 'open a NEW terminal so PATH changes apply, then start nvim once: Mason installs the language servers'
