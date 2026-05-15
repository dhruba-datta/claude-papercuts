# unclear.tape — vhs script for the /unclear demo GIF.
#
# Render with:    vhs demos/unclear.tape
# Output:         demos/unclear.gif
#
# Style: GitHub Dark, JetBrains Mono 18pt, 1080x720 @ 4fps.

Output demos/unclear.gif

Set Theme "GitHub Dark Default"
Set FontFamily "JetBrains Mono"
Set FontSize 18
Set Width 1080
Set Height 720
Set TypingSpeed 50ms
Set Padding 24
Set PlaybackSpeed 1.0

# --- Act 1: rich Claude session, lots of context ---

Type "claude"
Enter
Sleep 800ms

Type "Refactor the auth middleware to drop the cookie-based session in favor of bearer tokens. Keep the rate limiter unchanged."
Enter
Sleep 2s

# (in a real demo, this is where the recording would capture Claude's
# actual response — for the .tape file we just simulate progress with
# a comment block the user can replay over the real recording)

# --- Act 2: the accident ---

Sleep 1500ms
Type "/clear"
Enter
Sleep 1500ms

# Beat — empty terminal, cursor blinking, "horror"
Sleep 2s

# --- Act 3: recovery ---

Type "/unclear"
Enter
Sleep 3s

# Hold on the recap so it shows as the Twitter preview thumbnail
Sleep 2s
