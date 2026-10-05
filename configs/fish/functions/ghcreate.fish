function ghcreate --description 'create a GitHub repo with gh (private unless -p)'
    argparse p/public 'd/description=' h/help -- $argv; or return 1
    if set -q _flag_help
        echo 'usage: ghcreate [name] [-p|--public] [-d description]'
        return 0
    end
    set -l base $HOME/workspace/github
    set -q GH_CLONE_DIR; and set base $GH_CLONE_DIR
    set -l visibility --private
    set -q _flag_public; and set visibility --public
    set -l extra
    set -q _flag_description; and set extra --description $_flag_description
    __gh_ready; or return 1
    set -l name $argv[1]
    if test -z "$name"
        set -l top (git rev-parse --show-toplevel 2>/dev/null)
        if test -z "$top"
            echo 'not in a git repo; pass a name to create a new one' >&2
            return 1
        end
        if git remote get-url origin >/dev/null 2>&1
            echo 'origin is already set' >&2
            return 1
        end
        if not git rev-parse --verify -q HEAD >/dev/null
            echo 'make a commit first' >&2
            return 1
        end
        cd $top; or return 1
        set name (basename $top)
    else
        set -l dest $base/$name
        if test -e $dest
            echo "already exists: $dest" >&2
            return 1
        end
        mkdir -p $dest; and cd $dest; or return 1
        git init -q -b main; and printf '# %s\n' $name >README.md; and git add README.md; and git commit -q -m 'Initial commit'; or return 1
    end
    gh repo create $name $visibility $extra --source=. --remote=origin --push
end
