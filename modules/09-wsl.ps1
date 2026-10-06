$ErrorActionPreference = 'Stop'
. (Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'helper') 'helper.ps1')

Write-Step 'WSL 2 (needed by Docker Desktop)'

if (Test-DryRun) {
    Write-Host '    [dry-run] enable Microsoft-Windows-Subsystem-Linux and VirtualMachinePlatform, wsl --update'
    return
}

$restart = $false
foreach ($feature in 'Microsoft-Windows-Subsystem-Linux', 'VirtualMachinePlatform') {
    try {
        $state = (Get-WindowsOptionalFeature -Online -FeatureName $feature -ErrorAction Stop).State
        if ($state -eq 'Enabled') { Write-Info "$feature already enabled"; continue }
        $r = Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart -ErrorAction Stop
        if ($r.RestartNeeded) { $restart = $true }
        Write-Ok "enabled $feature"
    } catch {
        Write-Warn "could not enable ${feature}: $($_.Exception.Message)"
    }
}

# Docker Desktop will not start unless the WSL package itself is current
function Update-Wsl {
    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) { return $false }
    $null = Invoke-Native { & wsl.exe --update --web-download }
    $code = $LASTEXITCODE
    if ($code -ne 0) { $null = Invoke-Native { & wsl.exe --update }; $code = $LASTEXITCODE }
    $null = Invoke-Native { & wsl.exe --set-default-version 2 }
    return ($code -eq 0)
}

if (Update-Wsl) {
    Write-Ok 'WSL 2 is up to date'
} elseif ($restart) {
    # features only become usable after a reboot: finish the update at next logon
    try {
        $cmd = '-NoProfile -WindowStyle Hidden -Command "wsl.exe --update --web-download; if ($LASTEXITCODE -ne 0) { wsl.exe --update }; wsl.exe --set-default-version 2; Unregister-ScheduledTask -TaskName DotsWslUpdate -Confirm:$false"'
        $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $cmd
        $trigger = New-ScheduledTaskTrigger -AtLogOn
        $princ = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -RunLevel Highest
        Register-ScheduledTask -TaskName 'DotsWslUpdate' -Action $action -Trigger $trigger -Principal $princ -Force | Out-Null
        Write-Warn 'reboot required, WSL will finish updating at next logon'
    } catch {
        Write-Warn "reboot, then run: wsl --update"
    }
} else {
    Write-Warn 'WSL update did not complete, run: wsl --update'
}
