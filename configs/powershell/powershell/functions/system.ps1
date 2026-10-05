# Port of bash/functions/system.bash

function Test-CommandExists {
    param([Parameter(Mandatory)][string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function psg {
    param([string]$Name)
    if (-not $Name) {
        Write-Host "Usage: psg <process_name>"
        return
    }
    Get-Process | Where-Object { $_.ProcessName -match $Name } |
        Format-Table Id, ProcessName, CPU, WS -AutoSize
}

function sysinfo {
    Write-Host "=== System Information ==="
    Write-Host "Hostname: $env:COMPUTERNAME"
    Write-Host "Kernel:   $([System.Environment]::OSVersion.VersionString)"

    $os = Get-CimInstance Win32_OperatingSystem
    $uptime = (Get-Date) - $os.LastBootUpTime
    Write-Host "Uptime:   $($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m"

    $memUsedGB = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB, 2)
    $memTotalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    Write-Host "Memory:   ${memUsedGB}GB / ${memTotalGB}GB"

    # Windows has no direct "load average" equivalent - CPU load is
    # instantaneous, not a rolling average the way uptime reports it on
    # Linux. Closest honest substitute:
    $cpuLoad = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
    Write-Host "CPU load: ${cpuLoad}%"

    $disk = Get-PSDrive -Name ($env:SystemDrive -replace ':', '')
    $diskUsedGB = [math]::Round(($disk.Used) / 1GB, 1)
    $diskTotalGB = [math]::Round(($disk.Used + $disk.Free) / 1GB, 1)
    Write-Host "Disk:     ${diskUsedGB}GB / ${diskTotalGB}GB"
}

function install_tools {
    Write-Host "Installing fzf and ripgrep..."

    if (-not (Test-CommandExists fzf)) {
        Write-Host "Installing fzf..."
        winget install --id junegunn.fzf -e
    } else {
        Write-Host "fzf already installed"
    }

    if (-not (Test-CommandExists rg)) {
        Write-Host "Installing ripgrep..."
        winget install --id BurntSushi.ripgrep.MSVC -e
    } else {
        Write-Host "ripgrep already installed"
    }

    Write-Host "Tools installation complete!"
    Write-Host "Reload your profile with: reload"
}
