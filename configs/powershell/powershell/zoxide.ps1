# Port of bash/zoxide.bash.
#
# UNVERIFIED, unlike the rest of this port - I couldn't get a zoxide
# binary through this sandbox's allowed network domains, so this is
# written from documentation, not tested execution like everything else
# here. `zoxide init powershell` is the officially documented subcommand
# and has existed for a long time, so confidence is reasonably high, but
# say so plainly rather than imply the same verification level as the
# other files.

if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    (zoxide init powershell) | Out-String | Invoke-Expression
}
