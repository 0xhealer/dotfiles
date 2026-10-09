# This file used to hand-roll its own `prompt` function (a PowerShell port
# of bash/prompt.bash) with no connection to Starship at all. That's why
# starship.toml was never actually rendering: this function was defining
# `prompt` first, then zoxide.ps1 (loaded alphabetically after this file)
# wrapped THIS function as $__zoxide_prompt_old - starship.exe was never
# invoked anywhere in the chain.
#
# Fix: let Starship's own init define `prompt` instead. This one line does
# everything the old hand-rolled function did (time/user/host/dir/git/exit
# status/champagne character) via starship.toml, plus every language
# module in that file, which the old function had no way to replicate.
# Because this still loads alphabetically before zoxide.ps1, zoxide will
# wrap the REAL starship prompt function this time instead of a dead one.
Invoke-Expression (&starship init powershell)

# One-line session banner in the ButterZsh layout, values only, same as zsh and fish:
#   — host kernel ip · wm · shell —
function Show-DotsHeader {
    if ($script:_DotsHeaderShown -or $Host.Name -ne 'ConsoleHost') { return }
    $script:_DotsHeaderShown = $true

    $os = [System.Environment]::OSVersion.Version
    $kernel = "$($os.Major).$($os.Minor).$($os.Build)"
    $hostName = $env:COMPUTERNAME.ToLower()

    $ip = [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() |
        Where-Object { $_.OperationalStatus -eq 'Up' -and $_.NetworkInterfaceType -ne 'Loopback' } |
        Where-Object { $_.GetIPProperties().GatewayAddresses.Count -gt 0 } |
        ForEach-Object { $_.GetIPProperties().UnicastAddresses } |
        Where-Object { $_.Address.AddressFamily -eq 'InterNetwork' } |
        Select-Object -First 1 -ExpandProperty Address

    $parts = "`e[38;5;212m—`e[0m `e[1;97m$hostName`e[0m `e[97m$kernel`e[0m"
    if ($ip) { $parts += " `e[97m$ip`e[0m" }
    $parts += " `e[2m·`e[0m `e[38;5;114mdwm`e[0m `e[2m·`e[0m `e[38;5;213mpwsh $($PSVersionTable.PSVersion)`e[0m `e[38;5;212m—`e[0m"
    Write-Host $parts
    Write-Host ''
}

Show-DotsHeader
