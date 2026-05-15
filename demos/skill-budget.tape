# skill-budget.tape — vhs script for the skill-budget demo GIF.
#
# Render with:    vhs demos/skill-budget.tape
# Output:         demos/skill-budget.gif
#
# Style: GitHub Dark, JetBrains Mono 14pt, 1080x720 @ 24fps.
# (Font size 14 because the audit output has long lines.)

Output "demos/skill-budget.gif"

Set Theme "GitHub Dark"
Set FontFamily "JetBrains Mono"
Set FontSize 14
Set Width 1080
Set Height 720
Set Padding 24
Set PlaybackSpeed 1.0
Set Framerate 24

Hide
Type "clear && bash demos/scenario-skill-budget.sh"
Enter
Show

Sleep 16s
