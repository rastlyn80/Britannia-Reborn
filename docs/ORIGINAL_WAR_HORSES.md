# Original Silver, faction, Ethereal and Pack Horses

The optional Enhanced profile uses these original Third Dawn forms. The worn item and body on the wire remain authoritative.

| Native form | Body | Worn item | Third Dawn artwork |
| --- | ---: | ---: | --- |
| Silver Steed, Holy Steed | 117 | `0x3EA8` | `equines_horse_silver_steed` |
| True Britannians Warhorse | 118 | `0x3EB2` | `equines_horse_war_brittanian` |
| Council of Mages Warhorse | 119 | `0x3EB1` | `equines_horse_war_mage_council` |
| Minax Warhorse | 120 | `0x3EAF` | `equines_horse_war_minax` |
| Shadowlords Warhorse | 121 | `0x3EB0` | `equines_horse_war_shadowlord` |
| Ethereal Horse | 200 (worn-item proxy) | `0x3EAA` | `equines_horse_ethereal` (historical body 115) |
| Pack Horse | 291 | | `equines_horse_dappled_brown_pack` |

Silver and Ethereal share verified original geometry and use their own atlases. The faction horses also share verified geometry with a separate original coat for each faction. Pack Horse has a separate 36-triangle cargo surface rigidly attached to its original load joint. The native corpse graphic `0x2006` retains that surface and the server hue. The other living forms use the same body-aware corpse path. The Ethereal Horse is an item-only form.

Body 118 has twelve indexed Enhanced groups. Pack Horse has thirteen. Their 1,235 decoded frames supplied the reference for nineteen fitted motions, including both falls. Three original gaits are retained on each rig. Pack Horse group 28 contains one neutral frame per direction, so its fit holds a neutral pose. The official data indicates forty frames for that group. The [reference ledger](../scripts/war-horse-sequences.json) records both counts and the archive member hashes. The other forms retain their verified Third Dawn clips. Holy Steed uses the authored breath clip for the stock five-frame selector and launches the native `0x36D4` effect from the muzzle.

Build with `python -B scripts/prepare-original-war-horses.py --models <private Third Dawn Models directory> --install`, then launch the client with its prepared Enhanced profile. The recipe verifies the original model table, meshes, motion members and atlases. Generated scenes and atlases stay under `Viewer/local-art/mounts`. Run `scripts/verify.ps1` to exercise the Classic and Enhanced client routes and the mounted and terrain tests.

The replay passed 19 Classic and 210 Enhanced checks. Both human rigs passed 3,600 assertions over 648 mounted poses, including robes and plate. Terrain checks passed 5,301 source and fall poses, 4,329 supported poses and 63 fall transfers. The largest transfer displacement was 0.90 micrometres. Forward+ rendered 75 views across the indexed actions. A fresh recipe build reproduced the rigs, geometry, atlases and 1,724 animation tracks. The separate Holy Steed test passed 23 native checks with controlled targeting, including stock projectile and damage timing.

Two disposable ModernUO clients passed 561 checks across 38 rider and constructor cases. The test covered the native faction permissions and spoken ethics oaths, normal mount and dismount, full and partial dyes, and walking and running. Native Pack Horse use opened its real backpack. Both clients observed the stock deaths and the client retained the cargo on the dyed static Pack Horse corpse. The fixture set up ownership, faction rank and the test arena, and sent a controlled recoil action.
