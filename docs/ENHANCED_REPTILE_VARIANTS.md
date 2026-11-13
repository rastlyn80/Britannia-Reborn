# Enhanced Raptor and Slith action variants

Ultima Online Enhanced Client 4.0.117.33 identifies the named sequence members as `0x9fed8396eb2a2d` for Raptor 730 and `0xafc4399ccb01be12` for Slith 734. Both use group 4 or 5 for the selected attack, group 2 or 3 for the selected fall, and group 10 for the hit reaction. Peace mode inherits those actions from combat mode. The two bodies retain the Quaternius CC0 velociraptor and the local Third Dawn Komodo Dragon rigs respectively.

The recovered `AnimationFrame2.uop` members are zlib-compressed AMOU v1 sprites. The expanded header starts with `41 4d 4f 55 01 00 00 00`. The table records the exact Enhanced patch members and decoded frame counts across five directions. Their sprite sequences were used as pose references for the fitted 3D clips.

| Body | Group | Archive index | Patch member key | Decoded frames |
| --- | ---: | --- | --- | ---: |
| 730 | 2 | `AnimationFrame2.uop_2.mft` | `26de7d24156bd75b` | 50 |
| 730 | 3 | `AnimationFrame2.uop_1.mft` | `1f026aa258fea490` | 35 |
| 730 | 5 | `AnimationFrame2.uop_d.mft` | `ddda62ca161c60e6` | 45 |
| 730 | 10 | `AnimationFrame2.uop_c.mft` | `c8409f8a89847ff3` | 35 |
| 734 | 2 | `AnimationFrame2.uop_e.mft` | `e6905fad4f5394ed` | 50 |
| 734 | 3 | `AnimationFrame2.uop_f.mft` | `fa169facc847333d` | 40 |
| 734 | 5 | `AnimationFrame2.uop_4.mft` | `49f8dcae33dcbea4` | 45 |
| 734 | 10 | `AnimationFrame2.uop_6.mft` | `67c497ba35f8f4a8` | 35 |

## Reproducing the optional local profile

1. Obtain the pinned Enhanced `AnimationSequence.uop` and the listed members from the official client patch stream. The recorded member URL pattern for this build is `http://patch.ak-cdn.eamythic.com/uopatch-sa/283/release/uo/files/base/AnimationFrame2.uop/<key>`. Keep payloads local. Expand each member into `ec-frame-<body>-<group>.bin`. The profile builder checks the exact expanded digests, sequence SHA-256, mode fallback, and frame counts. The source client download is listed on the official site. [Ultima Online client download](https://uo.com/client-download/)
2. Prepare the original seven Enhanced motions with `scripts/bake-raptor-slith-enhanced.gd` and the existing Enhanced profile instructions in [progress](PROGRESS.md). Run Godot with `--headless --path Viewer --script res://../scripts/bake-enhanced-reptile-variants.gd` to generate the six fitted scenes below the ignored creature work directory.
3. Run `python -B scripts/prepare-enhanced-reptile-variants.py --reference <expanded-frames> --sequence <AnimationSequence.uop> --scenes <fitted-scenes> --output-viewer Viewer` to install the optional local profile. Run `test-enhanced-reptile-variants-world.gd` with the fixture world in both the Classic and Enhanced presentations. The original Enhanced profile remains usable if this extension is absent or fails its digest checks.

The World fixture exercises decoded 0xE2 inputs in both modes and checks the matching frozen graphic 0x2006 body, hue and clip. The terrain tests cover level ground, slopes and raised treads. The stock server's genuine Raptor and Slith combat and breath trials are tracked separately because its gameplay path sends Classic actions.
