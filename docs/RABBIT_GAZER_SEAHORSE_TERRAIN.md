# Rabbit, Gazer and Sea Horse terrain

| Body | Terrain poses | Decoded corpse handoffs | Isolated native checks |
| --- | ---: | ---: | ---: |
| Rabbit 205 | 3,906 Classic and 5,642 Enhanced | 64 Classic and 80 Enhanced | 109 Classic and 109 Enhanced |
| Gazer 22 | 3,906 Classic and 6,944 Enhanced | 64 Classic and 88 Enhanced | 89 Classic and 93 Enhanced |
| Sea Horse 144 | 6,510 Enhanced and 120 ridden fits | 64 Enhanced | 47 Enhanced |

## Rabbit and Vorpal Bunny

The public body and fur use the independent CC0 rabbit rig from [Čestmír Dammer](https://opengameart.org/content/rabbit-0). The project retains the original 37 joints, eight skin influences, separate alpha fur and pinned maps. See [Rabbit source and licence](RABBITS.md).

The native Rabbit, JackRabbit, wild Vorpal Bunny and talisman summon each retain the stock constructor and hues. The sampled 22 cm step previously cut into the skinned body by up to 220 mm. Both surfaces now clear that step while the original burrow can still take the rabbit more than 437 mm below the surface. The two isolated clients verified the stock tunnel notice, actual hole, timed deletion for the summon and the frozen body and fur after the wild bunny died during descent. The highest step still shifts the model upward by about 149 mm in one sampled lunge interval.

## Gazer and Elder Gazer

Both real MageAI classes use body 22 and retain their distinct stock strength ranges. The original Third Dawn mesh, UVs and four eye components remain intact. The exact source context is in [Gazer hover and Harpy surfaces](GAZERS_AND_HARPIES.md).

The second attack previously clipped the high tread by about 62 mm. The support adjustment preserves positive hover and updates eye flash positions after clearance. Native idle fidgets yield to a new move, and strikes retain their own timing. The isolated trials overlapped the stock idle fidget with a real run, followed the animated eye sockets, and resolved a stock Lightning cursor to actual damage and replicated effects. The native Gazer corpse retains its four stock Nightshade. The highest sampled attack still lifts the model by about 65 mm in one interval.

## Sea Horse

Body 144 and ridden item `0x3EB3` retain the stock SeaHorse identity. The optional distinct model is a reconstruction from 765 registered Enhanced frames, sequence `0xed9ffc90ed69c840` and the recovered original Third Dawn colour atlas. The inspected rider files contain skeleton animation tracks. The Classic profile keeps its documented horse-art fallback. [Sea Horse source evidence](PROGRESS.md) and [native identity](SEA_HORSES.md).

The tail rotates locally to clear the upper tread. The original collision test found up to 218 mm of penetration. The corrected model keeps roughly 3 mm of minimum clearance, and the worst one-interval change during its test walk and run is about 10 and 7 mm respectively. The highest-step hit still lifts the model by about 137 mm in one interval. The fitted saddle, both stirrups and both closed rein grips passed 120 measured poses with both human rigs. The two isolated clients repeated stock mounting, walking, running, dismounting and the exact native corpse with its raw hue. ModernUO keeps the native walking, untamable and non-swimming flags.

## Reproduction

Run `scripts/verify.ps1` with the prepared local source and optional Enhanced scenes. `test-rabbit-gazer-seahorse-terrain.gd` accepts body 22, 144 or 205 via `--body=` after the Godot argument separator. The mounted and corpse scripts use the same collision samples. Add `--enhanced-creature-actions` for the optional profile and for the distinct Sea Horse. The native trials used the local disposable server at loopback port 2594.
