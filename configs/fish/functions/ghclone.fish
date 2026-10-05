function ghclone --description 'clone a GitHub repo with gh into ~/workspace/github'
    set -l base $HOME/workspace/github
    set -q GH_CLONE_DIR; and set base $GH_CLONE_DIR
    if test (count $argv) -lt 1
        echo 'usage: ghclone <repo|owner/repo|url> [dir]' >&2
        return 1
    end
    __gh_ready; or return 1
    set -l repo $argv[1]
    if not string match -q '*/*' -- $repo
        set repo (gh api user --jq .login)/$repo
    end
    set -l name (string replace -r '\.git$' '' -- (basename $repo))
    set -l dest $base/$name
    test (count $argv) -ge 2; and set dest $argv[2]
    mkdir -p (dirname $dest)
    if test -d $dest/.git
        echo "already cloned: $dest"
    else
        gh repo clone $repo $dest; or return 1
    end
    cd $dest
end
