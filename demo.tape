# ClipSlots terminal demo
# Run with: vhs demo.tape

Output docs/images/demo.gif

Set Shell "zsh"
Set FontSize 14
Set Width 1100
Set Height 620
Set Theme { "name": "ClipSlots", "black": "#17112A", "red": "#ff5f57", "green": "#7DDFB0", "yellow": "#febc2e", "blue": "#8B5FBF", "magenta": "#B088D0", "cyan": "#7DDFB0", "white": "#C9BFD9", "brightBlack": "#7B6A96", "brightRed": "#ff5f57", "brightGreen": "#93E8BF", "brightYellow": "#febc2e", "brightBlue": "#9E75CF", "brightMagenta": "#C9BFD9", "brightCyan": "#93E8BF", "brightWhite": "#F0EBF5", "background": "#17112A", "foreground": "#C9BFD9", "selectionBackground": "#8B5FBF", "cursorColor": "#7DDFB0" }
Set Padding 20
Set Framerate 30
Set TypingSpeed 50ms

# Custom prompt: teal "$ " prompt, teal input text.
# Alias clipslots to the wrapper that forces colour + fakes Accessibility=Granted.
Hide
Type "export PS1=$'%{\e[32m%}$ '"
Enter
Type "preexec() { echo -ne '\e[0m'; }"
Enter
Type "precmd() { echo -ne '\e[32m'; }"
Enter
Type "alias clipslots='./demo-wrapper.sh'"
Enter

# Pre-populate slots with relatable content (as if saved via hotkeys)
Type "clipslots clear 1 2>/dev/null; clipslots clear 2 2>/dev/null; clipslots clear 3 2>/dev/null; clipslots clear 4 2>/dev/null; clipslots clear 5 2>/dev/null"
Enter
Type "echo 'jane@acme.com' | pbcopy && clipslots save 1"
Enter
Type "echo 'SELECT * FROM orders WHERE status = pending;' | pbcopy && clipslots save 2"
Enter
Type "echo 'Bearer eyJhbGciOiJIUzI1NiJ9.xxxx' | pbcopy && clipslots save 3"
Enter
Type "echo 'git rebase -i HEAD~3' | pbcopy && clipslots save 4"
Enter
Type "clipslots label 3 token"
Enter
Type "clipslots lock 3"
Enter
Type "clear"
Enter
Show

Sleep 500ms

# 1. The breadth — show the full command set up front
Type "clipslots --help"
Enter
Sleep 4.5s

Enter
Sleep 300ms

# 2. The hero — fastfetch-style status with logo
Type "clipslots status"
Enter
Sleep 4s

Enter
Sleep 300ms

# 3. Slots overview, with a labelled + locked slot visible
Type "clipslots list"
Enter
Sleep 3.5s

Enter
Sleep 300ms

# 4. Lock protects against overwrite
Type "echo 'should not overwrite' | pbcopy && clipslots save 3"
Enter
Sleep 2.5s

Enter
Sleep 300ms

# 5. Undo restores prior content
Type "echo 'wrong text' | pbcopy && clipslots save 1"
Enter
Sleep 1.5s
Type "clipslots undo 1"
Enter
Sleep 2s
Type "clipslots peek 1"
Enter
Sleep 2.5s

Sleep 1s
