function __gh_ready
    if not type -q gh
        echo 'gh is not installed' >&2
        return 1
    end
    gh auth status >/dev/null 2>&1; or gh auth login; or return 1
end
