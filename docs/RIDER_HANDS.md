# Rider hand and arm correction

The rein pose uses a relaxed finger curl, an opposed thumb and a wrist aligned with the forearm. Forearm rotation brings the thumb edge upward. Elbow poles are measured in saddle space so the pose works across the different mount rigs. Rein ends attach inside the palm rather than at the wrist joint. Only available hands receive this fitting; weapon, shield and ranged action guards remain in place. Dismount restores ordinary equipment grips.

Reproduce from the repository root with the local prepared human and mount art installed:

```powershell
./scripts/test-horses.ps1 -Gpu
# Optional actual close-up captures:
& ./.tools/godot/Godot_v4.7.2-stable_win64_console.exe --path Viewer --script res://Presentation/RiderHandsTests.gd -- --capture
```

The dedicated test passes 2,418 checks over 576 hand samples: both human bodies, four travel speeds, four animation phases, horse/ostard/llama/ki-rin rigs, robes, plate armour, sword, shield, bow and crossbow, plus dismount cleanup. Measurements are taken during `modification_processed`, while the fitted skin pose exists; ordinary frame callbacks see Godot's restored animation pose. Actual Forward+ close-ups were reviewed. Mounted and transition clothing checks pass 512 poses with zero failures.

Local evidence and captures live under ignored `outputs/rider-hands/`; clothing evidence is under `outputs/horse-session/`. These are bounded presentation checks, not new native mounting/gameplay claims or universal hand/object collision checks. No character assets or game-derived screenshots are committed.
