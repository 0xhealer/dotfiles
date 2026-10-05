# Mirrors configs/powershell/powershell/functions/utils.ps1

mkcd() { mkdir -p -- "$1" && cd -- "$1"; }

extract() {
  [[ -f $1 ]] || { echo "'$1' is not a valid file"; return 1; }
  case $1 in
    *.zip) unzip "$1" ;;
    *.tar.gz|*.tgz) tar xzf "$1" ;;
    *.tar.bz2|*.tbz2) tar xjf "$1" ;;
    *.tar.xz) tar xJf "$1" ;;
    *.tar.zst) tar --zstd -xf "$1" ;;
    *.tar) tar xf "$1" ;;
    *.7z) 7z x "$1" ;;
    *.gz) gunzip "$1" ;;
    *.bz2) bunzip2 "$1" ;;
    *.rar) unrar x "$1" ;;
    *) echo "'$1' cannot be extracted" ;;
  esac
}

hgrep() { fc -l 1 | grep -i -- "$1"; }

dirsize() { du -sh -- "${1:-.}"; }

path() { print -l ${(s/:/)PATH} | nl -w1 -s$'\t'; }

backup() {
  [[ -f $1 ]] || { echo "File not found: $1"; return 1; }
  local dest="$1.backup.$(date +%Y%m%d_%H%M%S)"
  cp -- "$1" "$dest" && echo "Backup created: $dest"
}

calc() { echo "scale=2; $*" | bc -l; }
