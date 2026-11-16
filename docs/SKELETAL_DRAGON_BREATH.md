# Skeletal Dragon cold breath

The Skeletal Dragon and Skeletal Dragon Renowned share native body 104. ModernUO starts their cold breath with Classic action 12, five frames, one repetition, and zero delay. It sends the moving graphic `0x36D4` with hue `0x0480` about 1.3 seconds later. The Renowned constructor uses mobile hue 906, independent of the projectile hue.

The client keeps the Third Dawn model and its 54-bone rig, extending the open-jaw part of the existing Ancient Wyrm `Attack2` motion fitted to that rig. It uses the skinned upper snout and lower jaw (`bip01 head` and `box14`) to locate the projectile. During that short action, overlapping melee cues and locomotion preserve the windup. Death preempts it. The archive-grounding modifier supports the living mesh on slopes, and the native corpse packets retain the body's hue on a frozen mesh.

| Third Dawn member | SHA-256 |
| --- | --- |
| `uotdb/uotd/Models/Monsters/dragons_dragon_skeletal_lod2.grn` | `d4323d1355f65fbcc4f5865aec2ae53352003bc1fc9b7559560a8fccd979fcff` |
| `uotdb/uotd/Models/Maps/Dragons_dragon_Skeletal_v01.tga` | `f01b16e473a3b12ca7d7e1340d3060ff644352e7ccf906a343c5d16e2e553e21` |
| `uotdb/uotd/Models/Monsters/dragons_wyrm_ancient_attack2.grn` | `6f11b172ab252d5c59f6f76b7dbd79570f90e9cc795bca6d794c6cab03b4dec3` |

The source model, motion and atlas are original Ultima Online inputs. The prepared scenes and render evidence stay local. The exact inputs and local scene paths are in the accepted creature index under `dragons_dragon_skeletal`.

With that local scene installed, `scripts/verify.ps1` runs the decoded World replay to check the jaw opening, cold effect tint, launch point, slope clearance, interruption, and static dyed corpse. It also checks the Enhanced route when its local index is present. Both modes passed 11 checks. Forward+ renders in both modes showed the launch point just ahead of the open jaw.

On a disposable ModernUO server, both native classes selected the ability through their stock AI. Classic and Enhanced each passed 18 checks. The four trials observed launches at 1,305–1,313 ms with zero measured separation from the animated muzzle. All four targets took damage. These trials used an isolated arena. Wild encounters and Renowned encounter progression remain to be checked.
