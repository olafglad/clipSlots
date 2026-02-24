# ClipSlots terminal demo
# Run with: vhs demo.tape

Output docs/images/demo.gif

Set Shell "zsh"
Set FontSize 16
Set Width 800
Set Height 500
Set Theme { "name": "ClipSlots", "black": "#17112A", "red": "#ff5f57", "green": "#7DDFB0", "yellow": "#febc2e", "blue": "#8B5FBF", "magenta": "#B088D0", "cyan": "#7DDFB0", "white": "#C9BFD9", "brightBlack": "#7B6A96", "brightRed": "#ff5f57", "brightGreen": "#93E8BF", "brightYellow": "#febc2e", "brightBlue": "#9E75CF", "brightMagenta": "#C9BFD9", "brightCyan": "#93E8BF", "brightWhite": "#F0EBF5", "background": "#17112A", "foreground": "#C9BFD9", "selectionBackground": "#8B5FBF", "cursorColor": "#7DDFB0" }
Set Padding 20
Set Framerate 30
Set TypingSpeed 50ms

# Set up custom prompt: teal "$ " prompt, teal input text
Hide
Type "export PS1=$'%{\e[32m%}$ '"
Enter
Type "preexec() { echo -ne '\e[0m'; }"
Enter
Type "precmd() { echo -ne '\e[32m'; }"
Enter
# Alias clipslots to wrapper that fixes "Accessible: No" in VHS headless env
Type "alias clipslots='./demo-wrapper.sh'"
Enter

# Pre-populate slots with relatable content (as if saved via hotkeys)
Type "echo 'meeting@company.com' | pbcopy && clipslots save 1"
Enter
Type "echo 'SELECT * FROM orders WHERE status = pending;' | pbcopy && clipslots save 2"
Enter
Type "echo 'Bearer eyJhbGciOiJIUzI1NiJ9.xxxx' | pbcopy && clipslots save 3"
Enter
Type "echo 'git rebase -i HEAD~3' | pbcopy && clipslots save 4"
Enter
Type "echo '⌘ Thanks for the quick review!' | pbcopy && clipslots save 5"
Enter
Type "clear"
Enter
Show

Sleep 500ms

# Check daemon status
Type "clipslots status"
Enter
Sleep 3s

Enter
Sleep 300ms

# See what's in the slots
Type "clipslots list"
Enter
Sleep 3.5s

Enter
Sleep 300ms

# Clear a slot
Type "clipslots clear 3"
Enter
Sleep 1.5s

Enter
Sleep 300ms

# Verify it's gone
Type "clipslots list"
Enter
Sleep 3.5s

Enter
Sleep 300ms

# Check config
Type "clipslots config"
Enter
Sleep 3.5s

Sleep 1s
