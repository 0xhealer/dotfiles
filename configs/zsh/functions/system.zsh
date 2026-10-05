# Mirrors configs/powershell/powershell/functions/system.ps1

command_exists() { (( $+commands[$1] )); }

psg() {
  [[ -n $1 ]] || { echo "Usage: psg <process_name>"; return 1; }
  ps aux | grep -i -- "[${1[1]}]${1[2,-1]}"
}

myip() {
  hostname -I 2>/dev/null | awk '{print $1}'
  printf 'External: '
  curl -s https://ifconfig.me; echo
}

sysinfo() {
  echo "=== System Information ==="
  echo "Hostname: $(hostname)"
  echo "Kernel:   $(uname -r)"
  echo "Uptime:   $(uptime -p | sed 's/^up //')"
  echo "Memory:   $(free -h | awk '/^Mem:/ {print $3 " / " $2}')"
  echo "CPU load: $(cut -d' ' -f1-3 /proc/loadavg)"
  echo "Disk:     $(df -h / | awk 'NR==2 {print $3 " / " $2}')"
}

_pm() {
  if (( $+commands[apt] )); then echo apt
  elif (( $+commands[dnf] )); then echo dnf
  elif (( $+commands[yay] )); then echo yay
  elif (( $+commands[paru] )); then echo paru
  elif (( $+commands[pacman] )); then echo pacman
  fi
}

update() {
  case $(_pm) in
    apt) sudo apt update ;;
    dnf) sudo dnf makecache ;;
    yay|paru|pacman) sudo pacman -Sy ;;
  esac
}

upgrade() {
  case $(_pm) in
    apt) sudo apt update && sudo apt upgrade -y ;;
    dnf) sudo dnf upgrade -y ;;
    yay) yay -Syu ;;
    paru) paru -Syu ;;
    pacman) sudo pacman -Syu ;;
  esac
}

uplist() {
  case $(_pm) in
    apt) apt list --upgradable ;;
    dnf) dnf check-update ;;
    yay|paru|pacman) pacman -Qu ;;
  esac
}

search() {
  case $(_pm) in
    apt) apt search "$@" ;;
    dnf) dnf search "$@" ;;
    yay) yay -Ss "$@" ;;
    paru) paru -Ss "$@" ;;
    pacman) pacman -Ss "$@" ;;
  esac
}

pinstall() {
  case $(_pm) in
    apt) sudo apt install -y "$@" ;;
    dnf) sudo dnf install -y "$@" ;;
    yay) yay -S --needed "$@" ;;
    paru) paru -S --needed "$@" ;;
    pacman) sudo pacman -S --needed "$@" ;;
  esac
}

remove() {
  case $(_pm) in
    apt) sudo apt remove "$@" ;;
    dnf) sudo dnf remove "$@" ;;
    yay|paru|pacman) sudo pacman -Rns "$@" ;;
  esac
}

install_tools() {
  local t
  for t in fzf ripgrep; do
    local bin=$t; [[ $t == ripgrep ]] && bin=rg
    if (( $+commands[$bin] )); then echo "$t already installed"; else echo "Installing $t..."; pinstall "$t"; fi
  done
  echo "Tools installation complete! Reload with: reload"
}

autoremove() {
  case $(_pm) in
    apt) sudo apt autoremove --purge ;;
    dnf) sudo dnf autoremove ;;
    yay | paru | pacman) pacman -Qdtq | sudo pacman -Rns - ;;
  esac
}
