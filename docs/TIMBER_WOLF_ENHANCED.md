# Timber Wolf and Injured Wolf

ModernUO uses body 225 for the ordinary Timber Wolf and for the Injured Wolf in Haochi's Trials. The client keeps the original Third Dawn Timber Wolf rig, coat, skin weights, Classic clips and corpse art. The server still supplies the body, hue, movement and death. The ordinary wolf can be tamed and receives a pack bonus. The Injured Wolf has its own stats, a partial hue, and a quest-specific death.

## Motion reference

The inspected Enhanced archive has no direct named sequence for body 225. Its expected name hash is `0x03b9295831e56c9d`. The Classic `body.def` and `corpse.def` tables link Grey Wolf graphics 25 and 27 to 225. The local comparison found the same 32 joint names, parents and rest transforms within Godot's comparison tolerance on all three treatments.

The Grey Wolf sequence for body 25 exists under name hash `0xa75e1b8ab72c15d6`. Its decoded 2,431-byte payload has SHA-256 `955679a9dfdb491c73b8c5357bcc2cad322d7de5bc0b243add9ff2236d3a52f5`. [The Grey Wolf build recipe](../scripts/prepare-wolf-grizzly-enhanced.py) records the six AMOU groups, 295 reference frames and member hashes. Groups 4, 15, 25, 26, 27 and 28 guide a snap, low recoil, quiet stand, scent watch, howl and ear alert. These are authored fits on the original Timber Wolf, inferred from the Grey Wolf reference and shared rig.

## Build and check

1. Prepare the accepted Third Dawn wolf scenes and the existing Grey Wolf Enhanced fit. The runtime checks the accepted body 225 scenes and the installed body 25 fit against all three variants in the local manifest.
2. Run `python -B scripts/prepare-timber-wolf-enhanced.py --install` from the repository root. Use `--study` to choose the private bake output directory or `--godot` to select the Godot console executable.
3. Run `python -B scripts/prepare-timber-wolf-enhanced.py --check-installed` and `./scripts/verify.ps1`. The verifier runs the normal world replay with both profiles and the skinned terrain test when the Timber Wolf manifest is installed.

The three independent rebakes matched the measured atlas, mesh arrays, skin binds, 32-joint skeleton and 730 animation tracks per variant. The bake measures all six clips over 61 frames per treatment. All archives, fitted scenes and images stay local.

## Verification

The normal world replay passed 9 Classic and 104 Enhanced checks, including attack and idle variants, moving out of an idle gesture, both stock falls, both corpse packet orders and late hues. The terrain test covered 4,860 poses and 162 fall transfers on a flat floor and two measured slopes. Across those samples the full skin cleared the ground by at least 1.99 mm, the nearest paw stayed within 24 mm and the largest sampled joint displacement at the fall handoff was 0.00045 mm. Forward+ rendered 21 views of the retained Timber Wolf rig.

Two isolated ModernUO clients passed 125 checks across the two native constructors with both player sexes. These checks covered stock taming, native refusal for the Injured Wolf, the ordinary wolf's pack bonus, movement, stock melee, controlled Enhanced action packets, the corpse body and late hue. The trial supplied the current quest stage and dealt a credited lethal hit. ModernUO advanced Haochi's third trial through its own kill and quest logic.
