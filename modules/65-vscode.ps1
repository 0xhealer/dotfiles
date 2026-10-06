$ErrorActionPreference = 'Stop'
. (Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'helper') 'helper.ps1')

Write-Step 'Visual Studio Code Insiders'

$userDir = Join-Path (Join-Path $env:APPDATA 'Code - Insiders') 'User'
Copy-Config -Source (Get-RepoPath 'configs/vscode/settings.json') -Destination (Join-Path $userDir 'settings.json')
Copy-Config -Source (Get-RepoPath 'configs/vscode/keybindings.json') -Destination (Join-Path $userDir 'keybindings.json')

Update-SessionPath
$extensions = @(Get-PackageList -Path (Get-RepoPath 'packages/vscode-extensions.txt'))
if (Test-DryRun) {
    foreach ($ext in $extensions) { Write-Host "    [dry-run] code-insiders --install-extension $ext" }
} elseif (Test-Command 'code-insiders') {
    $env:NODE_NO_WARNINGS = '1'
    foreach ($ext in $extensions) {
        $code = Invoke-Native { & code-insiders --install-extension $ext --force }
        if ($code -ne 0) { Write-Warn "extension failed: $ext" }
    }
} else {
    Write-Warn 'code-insiders not on PATH yet; restart the terminal and run: .\install.ps1 -Modules vscode'
}
