# Port of bash/fzf.bash

if (Get-Command fzf -ErrorAction SilentlyContinue) {
    function vf {
        $file = fzf --preview "bat --color=always {} 2>$null" 2>$null
        if (-not $file) { $file = fzf }
        if ($file) { & $env:EDITOR $file }
    }

    function fkill {
        param([int]$Signal = 9)
        $selected = Get-Process | Sort-Object CPU -Descending |
            Format-Table Id, ProcessName, CPU -AutoSize | Out-String |
            fzf --multi | ForEach-Object { ($_ -split '\s+')[1] }
        if ($selected) {
            $selected | ForEach-Object { Stop-Process -Id $_ -Force }
        }
    }

    $env:FZF_DEFAULT_OPTS = "--height 40% --layout=reverse --border --info=inline"

    if (Get-Command fd -ErrorAction SilentlyContinue) {
        $env:FZF_DEFAULT_COMMAND = "fd --type f --hidden --follow --exclude .git"
        $env:FZF_CTRL_T_COMMAND = $env:FZF_DEFAULT_COMMAND
        $env:FZF_ALT_C_COMMAND = "fd --type d --hidden --follow --exclude .git"
    }

    # NOT auto-verified against real fzf/PSFzf behavior - I don't have
    # fzf.exe available to test against in this sandbox. If PSFzf is
    # installed (Install-Module PSFzf), its own Ctrl+T/Alt+C bindings will
    # likely conflict with anything you bind manually here - pick one
    # approach, don't layer both.
    if (Get-Module -ListAvailable -Name PSFzf) {
        Import-Module PSFzf
        Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
    }
}
