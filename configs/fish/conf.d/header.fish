# One-line session banner in the ButterZsh layout, values only:
#   — host · ip · wm · shell —
status is-interactive; or return

function _dots_header
    set -l wm "$XDG_CURRENT_DESKTOP"
    test -n "$wm"; or set wm "$DESKTOP_SESSION"
    if test -z "$wm"
        for w in i3 niri sway hyprland openbox bspwm xfwm4 kwin_x11 kwin_wayland mutter awesome qtile xmonad
            if pgrep -x $w >/dev/null 2>&1
                set wm $w
                break
            end
        end
    end
    test -n "$wm"; or set wm tty

    set -l host (string split -m1 . (hostname))[1]
    set -l ip (hostname -I 2>/dev/null | awk '{print $1}')
    if test -z "$ip"
        set ip (ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i = 1; i < NF; i++) if ($i == "src") print $(i + 1)}')
    end

    printf '\e[38;5;212m—\e[0m \e[1;97m%s\e[0m' $host
    test -n "$ip"; and printf ' \e[2m·\e[0m \e[97m%s\e[0m' $ip
    printf ' \e[2m·\e[0m \e[38;5;114m%s\e[0m \e[2m·\e[0m \e[38;5;213mfish %s\e[0m \e[38;5;212m—\e[0m\n\n' $wm $version
end

if not set -q _DOTS_HEADER_SHOWN; and test "$TERM" != dumb; and isatty stdout
    set -gx _DOTS_HEADER_SHOWN 1
    _dots_header
end
