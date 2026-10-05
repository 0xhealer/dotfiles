_gh_ready() {
  command -v gh >/dev/null 2>&1 || { echo "gh is not installed" >&2; return 1; }
  gh auth status >/dev/null 2>&1 || gh auth login || return 1
}

ghclone() {
  local repo="${1:-}" base="${GH_CLONE_DIR:-$HOME/workspace/github}" name dest
  if [ -z "$repo" ]; then
    echo "usage: ghclone <repo|owner/repo|url> [dir]" >&2
    return 1
  fi
  _gh_ready || return 1
  case "$repo" in
    */*) ;;
    *) repo="$(gh api user --jq .login)/$repo" ;;
  esac
  name="${repo##*/}"
  name="${name%.git}"
  dest="${2:-$base/$name}"
  mkdir -p "$(dirname "$dest")"
  if [ -d "$dest/.git" ]; then
    echo "already cloned: $dest"
  else
    gh repo clone "$repo" "$dest" || return 1
  fi
  cd "$dest" || return 1
}

ghcreate() {
  local name="" visibility="--private" base="${GH_CLONE_DIR:-$HOME/workspace/github}" dest top
  local -a extra
  extra=()
  while [ $# -gt 0 ]; do
    case "$1" in
      -p | --public) visibility="--public" ;;
      -d | --description)
        extra=(--description "${2:-}")
        shift
        ;;
      -h | --help)
        echo "usage: ghcreate [name] [-p|--public] [-d description]"
        return 0
        ;;
      *) name="$1" ;;
    esac
    shift
  done
  _gh_ready || return 1
  if [ -z "$name" ]; then
    top="$(git rev-parse --show-toplevel 2>/dev/null)" || {
      echo "not in a git repo; pass a name to create a new one" >&2
      return 1
    }
    if git remote get-url origin >/dev/null 2>&1; then
      echo "origin is already set" >&2
      return 1
    fi
    git rev-parse --verify -q HEAD >/dev/null || {
      echo "make a commit first" >&2
      return 1
    }
    cd "$top" || return 1
    name="$(basename "$top")"
  else
    dest="$base/$name"
    if [ -e "$dest" ]; then
      echo "already exists: $dest" >&2
      return 1
    fi
    mkdir -p "$dest" && cd "$dest" || return 1
    git init -q -b main && printf '# %s\n' "$name" >README.md && git add README.md && git commit -q -m "Initial commit" || return 1
  fi
  gh repo create "$name" "$visibility" "${extra[@]}" --source=. --remote=origin --push
}
