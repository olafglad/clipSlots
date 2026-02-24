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
# \e[32m = green (maps to #7DDFB0 in our theme)
# The preexec trick resets color after Enter so output stays default
Hide
Type "export PS1=$'%{\e[32m%}$ '"
Enter
Type "preexec() { echo -ne '\e[0m'; }"
Enter
Type "precmd() { echo -ne '\e[32m'; }"
Enter
Type "clear"
Enter
Show

Sleep 500ms

# Start fresh
Type "clipslots status"
Enter
Sleep 2s

Type "clipslots list"
Enter
Sleep 2s

# Save some content to slots
Type "echo 'Hello from slot 1' | pbcopy && clipslots save 1"
Enter
Sleep 1.5s

Type "echo 'API_KEY=sk-abc123' | pbcopy && clipslots save 2"
Enter
Sleep 1.5s

Type "echo 'SELECT * FROM users;' | pbcopy && clipslots save 3"
Enter
Sleep 1.5s

# Show what's saved
Type "clipslots list"
Enter
Sleep 3s

# Paste one back
Type "clipslots paste 1 && pbpaste"
Enter
Sleep 2s

# Clear and verify
Type "clipslots clear 2"
Enter
Sleep 1.5s

Type "clipslots list"
Enter
Sleep 3s

Sleep 1s
