# Demos

Recording scripts for the launch GIFs. All demos use `vhs` (Charm):

```bash
brew install vhs
vhs demos/unclear.tape          # renders demos/unclear.gif
```

| Demo | Tape | GIF | Status |
|---|---|---|---|
| `/unclear` after `/clear` | [`unclear.tape`](unclear.tape) | `unclear.gif` | tape drafted, not rendered |
| `done-prover` catching a lie | `done-prover.tape` | `done-prover.gif` | planned |
| `skill-budget` invisible-skills | `skill-budget.tape` | `skill-budget.gif` | planned |

## Conventions

- 1080×720 GIF, 4 fps
- Font: JetBrains Mono 18pt
- Theme: GitHub Dark Default
- 20-second cap per demo; if longer, split
- Final frame: 2-second hold on the result so it shows as the X
  preview thumbnail
- No music, no logo, no captions baked in (captions go in the
  social-post body)

## Workflow

1. Edit the `.tape` file
2. Render: `vhs demos/<name>.tape`
3. Eyeball the GIF
4. Commit both the `.tape` and the rendered `.gif` so contributors
   can re-render without re-acting
