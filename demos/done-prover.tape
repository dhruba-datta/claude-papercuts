# done-prover.tape — vhs script for the done-prover demo GIF.
#
# Render with:    vhs demos/done-prover.tape
# Output:         demos/done-prover.gif
#
# Style: GitHub Dark, JetBrains Mono 16pt, 1080x720 @ 24fps.
# The actual playback is a deterministic shell script
# (demos/scenario-done-prover.sh) so renders are reproducible.

Output "demos/done-prover.gif"

Set Theme "GitHub Dark"
Set FontFamily "JetBrains Mono"
Set FontSize 16
Set Width 1080
Set Height 720
Set Padding 24
Set PlaybackSpeed 1.0
Set Framerate 24

Hide
Type "clear && bash demos/scenario-done-prover.sh"
Enter
Show

# Internal pacing via the scenario script.
Sleep 16s
