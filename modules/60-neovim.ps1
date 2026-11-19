$ErrorActionPreference = 'Stop'
. (Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'helper') 'helper.ps1')

Write-Step 'Neovim'

Update-SessionPath
if (-not (Test-DryRun)) {
    if (-not (Test-Command 'nvim')) { Write-Warn 'nvim not on PATH yet; restart the terminal after installation' }
    if (-not (Test-Command 'clang') -and -not (Test-Command 'gcc')) { Write-Warn 'no C compiler on PATH; treesitter parsers need clang (Build Tools LLVM component, see modules/05-buildtools.ps1)' }
    foreach ($tool in 'go', 'cargo', 'python', 'npm') {
        if (-not (Test-Command $tool)) { Write-Warn "$tool not on PATH; its Neovim language server cannot install until it is (restart the terminal)" }
    }

    if (-not (Test-Command 'tree-sitter')) {
        if (Test-Command 'npm') {
            & npm install -g tree-sitter-cli
            if ($LASTEXITCODE -ne 0) { Write-Warn 'npm install tree-sitter-cli failed' }
        } else {
            Write-Warn 'npm not found; tree-sitter-cli not installed'
        }
    }
}

Set-ConfigDir -Source (Get-RepoPath 'configs/nvim') -Destination (Join-Path $env:LOCALAPPDATA 'nvim')
Write-Info 'first launch of nvim downloads plugins, treesitter parsers and LSP servers'
