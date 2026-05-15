# unclear.tape — vhs script for the /unclear demo GIF.
#
# Render with:    vhs demos/unclear.tape
# Output:         demos/unclear.gif
#
# The actual playback is a deterministic shell script
# (demos/scenario-unclear.sh) so the GIF is reproducible — every
# render produces the same frames. The real skill is tested in
# tests/run-all.sh, not here.
#
# Style: GitHub Dark, JetBrains Mono 16pt, 1080x720.

Output "demos/unclear.gif"

Set Theme "GitHub Dark"
Set FontFamily "JetBrains Mono"
Set FontSize 16
Set Width 1080
Set Height 720
Set Padding 24
Set PlaybackSpeed 1.0
Set Framerate 24

Hide
Type "clear && bash demos/scenario-unclear.sh"
Enter
Show

# The scenario script has its own internal pacing (`sleep` calls).
# Wait for it to finish.
Sleep 18s
