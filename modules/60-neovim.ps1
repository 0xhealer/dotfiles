$ErrorActionPreference = 'Stop'
. (Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'helper') 'helper.ps1')

Write-Step 'Neovim'

Update-SessionPath
if (-not (Test-DryRun)) {
    if (-not (Test-Command 'nvim')) { Write-Warn 'nvim not on PATH yet; restart the terminal after installation' }
    if (-not (Test-Command 'gcc')) { Write-Warn 'gcc not found; treesitter parsers need it (WinLibs from packages/windows.txt)' }

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
