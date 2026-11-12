# Creature actions reached during stock gameplay

The broad ledger contains 6,489 mapped body/action slots out of 8,090. The installed Classic frame audit found no matching original Classic frame data for the 1,601 open combinations. Enhanced frame records have a separate inventory. A body can have a working display and native encounter behavior while the broad ledger still contains empty possibilities.

| Open category | Slots |
| --- | ---: |
| Cast and Cast3 | 548 |
| Bow, crossbow and throw | 649 |
| Flight and landing | 367 |
| Classic group 11 | 37 |

`python -B scripts/audit-creature-action-gaps.py` reads the action ledger, configured occurrence report and the pinned ModernUO checkout. It writes `outputs/creatures/action-gap-audit.json` with source hashes, source line numbers, runtime body types and candidates ranked by configured occurrence. To use the six-facet census, pass its JSON path via `--occurrence`.

## Stock approach animation

ModernUO's `BaseCreature.OnMovement` sends Classic group 11 when a visible player crosses the 18-tile notice range of an eligible monster. The packet has five frames, one cycle, no reverse or repeat flag and delay one. A creature with a combatant or a controlled, summoned or bard-pacified state is excluded by the stock branch.

The normal client now reuses the body's reviewed group 18 gesture for this specific notice when group 11 is unavailable. Corpser and Whipping Vine curl their tendrils, Gazer and Elder Gazer spread their eyes, Swamp Tentacle curls and rises, and Dull Copper Elemental uses its copper shift. The other verified bodies use their retained fidgets. The original packet remains in the action record, and a dedicated available group 11 has priority. These are explicit presentation substitutes for the approach cue.

| Verified body IDs | Stock constructors |
| --- | --- |
| 8, 22 | Corpser, WhippingVine, Gazer, ElderGazer |
| 49, 180, 106 | Both WhiteWyrm rolls, ShadowWyrm |
| 66, 129 | SwampTentacle, HarrowerTentacles |
| 89, 206, 215 | IceSerpent, LavaLizard, GiantRat |
| 94, 110, 135 | FrostOoze, DullCopperElemental, ArcticOgreLord |
| 142, 147, 168, 790 | RatmanArcher, SkeletalKnight, ShadowFiend, SandVortex |
| 107â€“109, 111â€“113, 166 | AgapiteElemental, BronzeElemental, CopperElemental, ShadowIronElemental, ValoriteElemental, VeriteElemental, GoldenElemental |

The isolated server tests passed 386 checks in each client mode. A real character walk triggered the stock packet in 38 scenarios per mode. Each of the 19 class/body combinations ran once with the normal client walking and once with it observing. Both connections received the original packet and the normal client's animation advanced. The four initial constructors reproduced the unsupported action on the baseline. World applies this fallback through `CreatureApproachActions.gd`. `CreatureActionRoutingTests.gd` checks the exact packet, untouched ordinary group 11 and explicit-route priority.

### Ore elementals

All seven bodies use the retained group 18 fidget for the stock notice. Isolated Classic and Enhanced runs each passed 188 checks across 14 scenarios. Each ore type ran once with the normal client walking and once with it observing. Both sessions received the original group 11 packet. The normal client played the fidget and displayed a frozen corpse with the matching body. The stock corpse held 25 units of the corresponding ore (item 0x19B9). The client routing test covers 166 cases, including the exact packet and priority of a dedicated action.

The fixture uses the same 25-ore constructor as the stock gargoyle pickaxe mining branch, then places the creature without a combatant to test the normal movement notice. Stock mining immediately sets the miner as combatant, so this test does not exercise the harvest roll or imply that a mining spawn opens with the notice.

## Remaining work

Twenty-four of the 37 audited group 11 entries now have isolated stock notice evidence. Check reachability for the remaining 13, including historical body variants and summoned forms, before assigning a replacement. The stock generic weapon swing returns early for monster bows and crossbows. Monster player forms can emit Classic group 12 when the stock casting timer runs, subject to the form and spell restrictions. Their exact reachable combinations still need testing. The optional Enhanced source graph, specialized scripts and effect-driven attacks retain their own checks.
