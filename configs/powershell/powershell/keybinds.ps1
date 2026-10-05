# Port of bash/keybinds.bash. Verified against real PSReadLine (bundled
# with pwsh) - all three handlers confirmed to set without error.

# Ctrl+L to clear screen
Set-PSReadLineKeyHandler -Chord "Ctrl+l" -Function ClearScreen

# Up/Down arrow for (prefix-aware) history search, not plain
# previous/next-line history. This is PSReadLine's closest built-in
# equivalent to bash's history-search-backward/forward.
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

# Word navigation and deletion, matching the zsh and fish keybinds
Set-PSReadLineKeyHandler -Chord "Ctrl+LeftArrow" -Function BackwardWord
Set-PSReadLineKeyHandler -Chord "Ctrl+RightArrow" -Function ForwardWord
Set-PSReadLineKeyHandler -Chord "Alt+LeftArrow" -Function BackwardWord
Set-PSReadLineKeyHandler -Chord "Alt+RightArrow" -Function ForwardWord
Set-PSReadLineKeyHandler -Chord "Ctrl+Backspace" -Function BackwardKillWord
Set-PSReadLineKeyHandler -Chord "Ctrl+Delete" -Function KillWord
