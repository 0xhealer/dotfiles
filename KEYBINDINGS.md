# Keybindings

Same keys on every Linux install. `Super` is the modifier. i3 (Ubuntu, Kali) and niri (CachyOS, Fedora) differ only in what some keys do.

| Keys | i3 | niri |
| --- | --- | --- |
| `Super+Return` | kitty | kitty |
| `Super+Shift+Return` | ghostty | ghostty |
| `Super+B` | Helium | Helium |
| `Super+E` | Thunar | Thunar |
| `Super+Space`, `Super+D` | rofi launcher | Vicinae |
| `Super+Shift+D` | dmenu run | Noctalia launcher |
| `Super+S` | pavucontrol | Noctalia control center |
| `Super+Shift+V` | CopyQ clipboard history | Noctalia clipboard |
| `Super+N` | toggle do-not-disturb | toggle do-not-disturb |
| `Super+Shift+N` | show last notification | - |
| `Super+Shift+/` | keybinding list | hotkey overlay |
| `Super+Q` | close window | close window |
| `Super+F` | fullscreen | fullscreen |
| `Super+M` | fullscreen | maximize column |
| `Super+V` | toggle floating | toggle floating |
| `Super+C` | center floating window | center column |
| `Super+Tab` | rofi window list | Noctalia window switcher |
| `Super+O` | rofi window list | overview |
| `Super+H/J/K/L`, arrows | focus | focus |
| `Super+Shift+H/J/K/L`, arrows | move window | move window/column |
| `Super+Ctrl+Left/Right` | focus other monitor | focus other monitor |
| `Super+Ctrl+Shift+Left/Right` | move workspace to monitor | move column to monitor |
| `Super+1..9` | workspace | workspace |
| `Super+Shift+1..9` | move window to workspace | move column to workspace |
| `Super+PageDown/PageUp` | next/previous workspace | next/previous workspace |
| `Super+R` | resize mode | cycle preset column width |
| `Super+-` / `Super+=` | shrink / grow width | shrink / grow width |
| `Super+T` | tabbed layout | tabbed column |
| `Super+W` | wallpaper picker (waypaper) | Wallpaper Carousel (needs quickshell, otherwise a random wallpaper) |
| `Super+Shift+W` | random wallpaper + new colors | random wallpaper |
| `Super+Ctrl+W` | pause/resume wallpaper rotation | pause/resume wallpaper rotation |
| `Super+Alt+L` | lock | lock |
| `Super+Shift+E` | power menu | Noctalia session menu |
| `Super+Shift+R` | reload i3 | reload Noctalia config |
| `Super+Shift+P` | screen off | screen off |
| `Print` | region to clipboard | screenshot |
| `Ctrl+Print` | full screen to file | screen screenshot |
| `Alt+Print` | window to clipboard | window screenshot |
| `Super+Shift+S` | region to clipboard | screenshot |
| volume, brightness, media keys | pactl, brightnessctl, playerctl | wpctl, brightnessctl, playerctl |

i3 only: `Super+Shift+C` restart i3, `Super+Ctrl+H/V` split, `Super+Ctrl+S` stacking, `Super+Shift+T` toggle split, `Super+,` / `Super+.` focus parent / child.
niri only: `Super+,` / `Super+.` consume / expel window from column.

GNOME (Ubuntu) and KDE (Kali) get the same keys through the `desktop` step, minus what they cannot do: no directional focus or move on GNOME (it tiles with `Super+Left/Right`), no split, stacking or tabbed keys, no `Super+Shift+N`, and `Super+N` (do not disturb) is GNOME only. The launcher keys open the GNOME overview or KRunner.

## Neovim

`Leader` is `Space`. Run `<leader>?` in Neovim for the full live list. Custom keys live in `configs/nvim/lua/core/keymaps.lua`.

VS Code keys carried over (`configs/vscode/keybindings.json`):

| VS Code | Neovim |
| --- | --- |
| `Alt+Up/Down` | move line or selection (also in insert) |
| `Alt+Shift+Up/Down` | duplicate line or selection |
| `Ctrl+S` | save (prompts for a name on a new buffer) |
| `Ctrl+A` | select all |
| `Ctrl+T` | toggle terminal |
| `Ctrl+Shift+E` | `Space e` explorer (oil) |
| `Ctrl+Alt+[` / `]` | `Space [` / `Space ]` fold / unfold |
| `Ctrl+Shift+Alt+[` / `]` | `Space {` / `Space }` fold all / unfold all |
| `Ctrl+B` (markdown) | wrap in `**bold**` |
| `Ctrl+Alt+Up/Down` | `Ctrl+Up/Down` add cursor above / below |
| `Ctrl+D` | `Space n` add cursor on next match |
| `Alt+Click` | `Ctrl+Click` add cursor |
| `Ctrl+Shift+A/B/X` | no equivalent (no activity bar, sidebar, or extensions view) |

Other custom keys:

| Keys | Action |
| --- | --- |
| `;f` / `;r` / `;;` | files / live grep / resume (Snacks) |
| `;e` / `;g` / `;n` | diagnostics / lazygit / notifications |
| `\\` | buffers |
| `Space f…` | Telescope finders (`ff` files, `fg` grep, `fr` recent, `fk` keymaps) |
| `sf` | file explorer (oil, float) |
| `Ctrl+H/J/K/L` | move between windows, also from a terminal |
| `ss` / `sv` | split horizontal / vertical |
| `Tab` / `Shift+Tab` | next / previous tab page |
| `]b` / `[b` | next / previous buffer |
| `gd` `gr` `gy` `K` | definition, references, type, hover |
| `Space ca` / `cr` / `cf` | code action / rename / format |
| `]d` / `[d` | next / previous diagnostic |
| `Space gb` / `gd` / `dv` | blame line / diff overlay / CodeDiff |
| `Space vh` / `vf` | Obsidian vault home / find note |
| `Space uc` | colorscheme picker |
| `Space p/P`, `d`, `c` | paste / delete / change without yanking |

Added plugins: `gs` flash jump, `gS` flash treesitter select, `Space R` search and replace (grug-far), `Space xx/xb/xl/xq` Trouble lists.
