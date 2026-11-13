# Enhanced Fire Gargoyle, Troglodyte and Enslaved Gargoyle

Three named sequence members in Enhanced 4.0.117.33 underpin these fits. Fire Gargoyle 130 uses `0xd83f64ba26d623e2`, Troglodyte and Lurg share body 267 and `0x2b234b45fde380c5`, and Enslaved Gargoyle 753 uses `0xfe9e4e0adb912e1c`. The checked loose `AnimationFrame4.uop` directory contains 20 matching AMOU v1 sprite files for these bodies. The 860 decoded frames show alternate attacks, recoil, reaches and collapses. The current fits retain the established rigs and base keys.

| Body | Source groups examined | Sprite frames |
| --- | --- | ---: |
| Fire Gargoyle | 2, 3, 10 | 130 |
| Troglodyte and Lurg | 2, 3, 4, 5, 10, 11, 15, 23 | 335 |
| Enslaved Gargoyle | 2, 3, 4, 5, 10, 11, 15, 23, 28 | 395 |

The World fixture drove 3,840 combat selections each for Troglodyte and Enslaved Gargoyle. Each of the three bodies passed a further 280 hit, fall and dyed corpse checks. Their two falls continued from the displayed pose into static graphic 0x2006. Across three terrain layouts the fall sweep covered 96 handoffs and 1,632 full-skin samples. Enslaved Gargoyle groups 11, 15 and 23 now select separate local fits for the low search, guard and rise.

The 0xE2 traffic was decoded client replay. The pinned server's stock behavior and the distinct named constructors have separate evidence.

## Local scene reproduction

Run the three `bake-enhanced-fire-gargoyle-variants.gd`, `bake-enhanced-troglodyte-combat.gd`
and `bake-enhanced-enslaved-combat.gd` scripts with the Viewer project and the existing local art.
Run `bake-enhanced-humanoid-falls.gd` afterwards for the two humanoid fall pairs.
