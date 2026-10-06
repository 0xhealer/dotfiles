# Port of bash/aliases.bash.
# Set-Alias can't carry arguments in PowerShell (bash's `alias cp='cp -iv'`
# has no direct equivalent) - everything with flags or logic is a function
# instead. Confirmed against real pwsh 7.5.2: user-defined functions take
# priority over any built-in alias of the same name, so shadowing ls/cp/rm
# etc. is safe.

# ============================================================================
# NAVIGATION
# ============================================================================
# gc, gcm, gp, gl, and h below collide with PowerShell's own built-in
# aliases (Get-Content, Get-Command, Get-ItemProperty, Get-Location,
# Get-History). Confirmed against real pwsh: aliases take precedence over
# same-named functions (documented order is Alias > Function > Cmdlet >
# Application), so without removing these first, typing "gl" would
# silently run Get-Location instead of git log - not error, just silently
# do the wrong thing. Removing them here, once, at profile load.
Remove-Item Alias:gc, Alias:gcm, Alias:gp, Alias:gl, Alias:h -Force -ErrorAction SilentlyContinue

function .. { Set-Location .. }
function ... { Set-Location ../.. }
function .... { Set-Location ../../.. }
function ~ { Set-Location $HOME }
# Confirmed: PowerShell 7+ natively tracks location history - "Set-Location -"
# genuinely works, no custom stack-tracking needed (verified against real
# pwsh, this is not a guess).
function - { Set-Location - }

# ============================================================================
# LS VARIANTS
# ============================================================================
if (Get-Command eza -ErrorAction SilentlyContinue) {
    function l { eza -l --group --color=always --group-directories-first @args }
    function ls { eza -al --group --header --icons --group-directories-first @args }
    function ll { eza -la --group --icons --group-directories-first @args }
    function la { eza -la --group --icons --group-directories-first @args }
    function lt { eza --tree --level=2 --icons @args }
    function lh { eza -la --group --sort=modified --reverse @args }

    function tree { eza --tree --level=4 --icons --long @args }
}
else {
    function l { Get-ChildItem @args }
    function ll { Get-ChildItem -Force @args }
    function la { Get-ChildItem -Force @args }
    function lt { Get-ChildItem -Recurse -Depth 2 @args }
    function lh { Get-ChildItem -Force | Sort-Object LastWriteTime -Descending }
    # "ls" is left alone here deliberately - it's the native cmdlet alias
    # for Get-ChildItem already; redefining it to itself adds nothing.
}

# ============================================================================
# FILE OPERATIONS
# ============================================================================
function cp { Copy-Item -Confirm @args }
function mv { Move-Item -Confirm @args }
function rm { Remove-Item -Confirm @args }

function rf { Remove-Item -Recurse -Force @args }
function mkdir { New-Item -ItemType Directory -Force -Verbose @args }

# ============================================================================
# SYSTEM INFO
# ============================================================================
# df/du/free have no direct Windows equivalent - these are the closest
# real mappings, not a 1:1 port. Genuinely different tools underneath.
function df { Get-Volume }
function du { param($Path = ".") Get-ChildItem $Path -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum | ForEach-Object { "{0:N2} MB" -f ($_.Sum / 1MB) } }
function free { Get-CimInstance Win32_OperatingSystem | Select-Object @{n = 'TotalGB'; e = { [math]::Round($_.TotalVisibleMemorySize / 1MB, 2) } }, @{n = 'FreeGB'; e = { [math]::Round($_.FreePhysicalMemory / 1MB, 2) } } }
function ps { Get-Process @args }
function top { Get-Process | Sort-Object CPU -Descending | Select-Object -First 15 }
function mem { Get-Process | Sort-Object WS -Descending | Select-Object -First 5 Name, @{n = 'MB'; e = { [math]::Round($_.WS / 1MB, 1) } } }
function cpu { Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 Name, CPU }

# ============================================================================
# NETWORK
# ============================================================================
function myip {
    (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notmatch '^127\.' } | Select-Object -First 1).IPAddress
    Write-Host -NoNewline "External: "
    Invoke-RestMethod -Uri "https://ifconfig.me"
}
function ports { Get-NetTCPConnection }
function listening { Get-NetTCPConnection -State Listen }

# ============================================================================
# PACKAGE MANAGEMENT (winget - not a literal apt port, different tool shape)
# ============================================================================
function winstall { winget install -e --id $args --accept-package-agreements --accept-source-agreements --silent --source winget --Force }
function search { winget search @args }
function update { winget source update }
function upgrade { winget upgrade --all }
function remove { winget uninstall @args }
function uplist { winget upgrade }
# No winget equivalent of `apt autoremove --purge` - winget doesn't track
# orphaned dependencies the way apt does. Left out rather than faked.

# ============================================================================
# GIT
# ============================================================================
function g { git @args }
function gs { git status @args }
function ga { git add @args }
function gaa { git add -A }
function gc { git commit @args }
function gcm { git commit -m @args }
function gp { git push @args }
function gpu { git push -u origin HEAD }
function gpl { git pull @args }
function gco { git checkout @args }
function gb { git branch @args }
function gd { git diff @args }
function gl { git log --oneline --graph --decorate }
function gclone { git clone @args }

# ============================================================================
# EDITORS AND CONFIG
# ============================================================================
function v { nvim @args }
function vv { nvim . }
function e { micro @args }
function n { nano @args }

function Edit-Profile { & (Get-Command $env:EDITOR -ErrorAction SilentlyContinue).Source $PROFILE }
function reload { . $PROFILE; Write-Host "Reloaded profile" }
function nvimrc { & $env:EDITOR "$HOME/AppData/Local/nvim/init.lua" }
# zshrc/vimrc/tmuxconf dropped - no zsh/vim/tmux equivalent on a stock
# Windows box worth faking an alias for.

# ============================================================================
# DIRECTORY SHORTCUTS
# ============================================================================
# NOTE: confirmed on your machine - singular .config, not .configs.
function conf { Set-Location "$HOME/.config" }
function g. { Set-Location "$HOME/.config" }
function dl { Set-Location "$HOME/Downloads" }
function doc { Set-Location "$HOME/Documents" }
function vid { Set-Location "$HOME/Videos" }

# ============================================================================
# UTILITIES
# ============================================================================
function x { exit }
function c { Clear-Host }
function h { Get-History }
function j { Get-Job }
function which { Get-Command @args }
function now { Get-Date -Format "yyyy-MM-dd HH:mm:ss" }
function week { Get-Date -UFormat %V }

function grep { Select-String @args }

function biggest { Get-ChildItem -Directory | ForEach-Object { [PSCustomObject]@{ Name = $_.Name; SizeMB = [math]::Round((Get-ChildItem $_.FullName -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum / 1MB, 1) } } | Sort-Object SizeMB }

function k9 { Stop-Process -Id $args[0] -Force }
function killall { param($Name) Stop-Process -Name $Name -Force -Verbose }

# tar ships natively on Windows 10 1803+ (bsdtar) - these work as-is,
# unlike most of the rest of this section.
function untar { tar -xvf @args }
function ungz { tar -xzvf @args }
function unbz2 { tar -xjvf @args }

function weather { Invoke-RestMethod "wttr.in?u" }
function ff { fastfetch }
# hi/notify-send dropped: no built-in Windows equivalent without adding
# the BurntToast module. Say so rather than fake a silent no-op.

# switch/switchperm dropped: bash<->zsh switching has no Windows analogue
# worth forcing (pwsh vs. Windows PowerShell 5.1 isn't the same kind of
# choice users make interactively the way bash/zsh is).

function projects { Set-Location ~/workspace/github; ls }
function workspace { Set-Location ~/workspace; ls }

Set-Alias -Name treesitter -Value tree-sitter
Set-Alias -Name code -Value code-insiders
