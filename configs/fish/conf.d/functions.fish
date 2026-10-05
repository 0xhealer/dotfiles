# Mirrors configs/powershell/powershell/functions/{utils,system}.ps1 and aliases.ps1

function mkcd
    mkdir -p -- $argv[1]; and cd -- $argv[1]
end

function extract
    if not test -f "$argv[1]"
        echo "'$argv[1]' is not a valid file"
        return 1
    end
    switch $argv[1]
        case '*.zip'
            unzip $argv[1]
        case '*.tar.gz' '*.tgz'
            tar xzf $argv[1]
        case '*.tar.bz2' '*.tbz2'
            tar xjf $argv[1]
        case '*.tar.xz'
            tar xJf $argv[1]
        case '*.tar.zst'
            tar --zstd -xf $argv[1]
        case '*.tar'
            tar xf $argv[1]
        case '*.7z'
            7z x $argv[1]
        case '*.gz'
            gunzip $argv[1]
        case '*.bz2'
            bunzip2 $argv[1]
        case '*.rar'
            unrar x $argv[1]
        case '*'
            echo "'$argv[1]' cannot be extracted"
    end
end

function hgrep
    history | grep -i -- $argv[1]
end

function dirsize
    du -sh -- (test (count $argv) -gt 0; and echo $argv[1]; or echo .)
end

function path
    set -l i 1
    for p in $PATH
        printf '%s\t%s\n' $i $p
        set i (math $i + 1)
    end
end

function psg
    if test (count $argv) -eq 0
        echo "Usage: psg <process_name>"
        return 1
    end
    ps aux | grep -i -- "[$(string sub -l 1 -- $argv[1])]$(string sub -s 2 -- $argv[1])"
end

function myip
    hostname -I 2>/dev/null | awk '{print $1}'
    printf 'External: '
    curl -s https://ifconfig.me; echo
end

function sysinfo
    echo "=== System Information ==="
    echo "Hostname: "(hostname)
    echo "Kernel:   "(uname -r)
    echo "Uptime:   "(uptime -p | sed 's/^up //')
    echo "Memory:   "(free -h | awk '/^Mem:/ {print $3 " / " $2}')
    echo "CPU load: "(cut -d' ' -f1-3 /proc/loadavg)
    echo "Disk:     "(df -h / | awk 'NR==2 {print $3 " / " $2}')
end

function _pm
    for m in apt dnf yay paru pacman
        if type -q $m
            echo $m
            return
        end
    end
end

function update
    switch (_pm)
        case apt
            sudo apt update
        case dnf
            sudo dnf makecache
        case yay paru pacman
            sudo pacman -Sy
    end
end

function upgrade
    switch (_pm)
        case apt
            sudo apt update; and sudo apt upgrade -y
        case dnf
            sudo dnf upgrade -y
        case yay
            yay -Syu
        case paru
            paru -Syu
        case pacman
            sudo pacman -Syu
    end
end

function uplist
    switch (_pm)
        case apt
            apt list --upgradable
        case dnf
            dnf check-update
        case yay paru pacman
            pacman -Qu
    end
end

function search
    switch (_pm)
        case apt
            apt search $argv
        case dnf
            dnf search $argv
        case yay
            yay -Ss $argv
        case paru
            paru -Ss $argv
        case pacman
            pacman -Ss $argv
    end
end

function pinstall
    switch (_pm)
        case apt
            sudo apt install -y $argv
        case dnf
            sudo dnf install -y $argv
        case yay
            yay -S --needed $argv
        case paru
            paru -S --needed $argv
        case pacman
            sudo pacman -S --needed $argv
    end
end

function remove
    switch (_pm)
        case apt
            sudo apt remove $argv
        case dnf
            sudo dnf remove $argv
        case yay paru pacman
            sudo pacman -Rns $argv
    end
end

function install_tools
    for t in fzf ripgrep
        set -l bin $t
        test $t = ripgrep; and set bin rg
        if type -q $bin
            echo "$t already installed"
        else
            echo "Installing $t..."
            pinstall $t
        end
    end
    echo "Tools installation complete! Reload with: reload"
end

function vf
    type -q fzf; or return 1
    set -l file (fzf --preview 'bat --color=always {} 2>/dev/null')
    test -n "$file"; and $EDITOR $file
end

function fkill
    type -q fzf; or return 1
    set -l sig 9
    test (count $argv) -gt 0; and set sig $argv[1]
    ps -eo pid,comm,%cpu --sort=-%cpu | fzf --multi --header-lines=1 | awk '{print $1}' | xargs -r kill -$sig
end

function backup
    if not test -f "$argv[1]"
        echo "File not found: $argv[1]"
        return 1
    end
    set -l dest "$argv[1].backup."(date +%Y%m%d_%H%M%S)
    cp -- $argv[1] $dest; and echo "Backup created: $dest"
end

function calc
    echo "scale=2; $argv" | bc -l
end

function command_exists
    type -q $argv[1]
end

function autoremove
    switch (_pm)
        case apt
            sudo apt autoremove --purge
        case dnf
            sudo dnf autoremove
        case yay paru pacman
            pacman -Qdtq | sudo pacman -Rns -
    end
end
