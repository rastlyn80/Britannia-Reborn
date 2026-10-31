# Creature work follows world occurrence

Owner priority: work from the creatures encountered most often to the least common. The active client configuration selects Trammel, so its full native spawn definitions take precedence over alphabetical asset families. Reuse work across related forms where appropriate; retain specific blockers and continue the ordered list.

`scripts/build-creature-priority.py` reads the active era's shared and post-UOML Trammel definitions, the pinned native class hierarchy, current body routes and native test receipts. It counts 2,137 configured spawners. The generated complete order contains 203 known non-human mobile types; human NPCs and item spawns are classified separately. Fourteen unresolved spawn type names remain explicit audit gaps.

Order is determined by probability-weighted shared spawn capacity, capped per entry, then by spawn locations. Mixed spawners share their total capacity; their capacity is not counted in full for every species. Items compete for capacity before being excluded. This is a configured occurrence proxy, **not a live headcount or exact equilibrium population**. The older live audit covers only the Britain region. Camp-generated creatures, quests, summons, manual placements, deaths and failed terrain placement are outside this estimate.

The top of the current order is:

| Order | Creature | Configured spawn locations |
|---:|---|---:|
| 1 | Bird | 253 |
| 2 | Orc | 238 |
| 3 | Water elemental | 167 |
| 4 | Kraken | 123 |
| 5 | Sea serpent | 121 |
| 6 | Deep sea serpent | 114 |
| 7 | Dolphin | 114 |
| 8 | Ettin | 242 |
| 9 | Hind | 223 |
| 10 | Rat | 78 |

Location counts alone are not the sort key: a smaller number of dense spawners can hold more creatures. Existing body routes do not mean final action, anatomy or terrain fidelity is complete. The full order retains integrated creatures for those remaining reviews; a separate missing-replacement view identifies absent graphics. Ordinary rat and cat routes are still missing despite giant-rat and wild-cat integration.

Rebuild with `python -B scripts/build-creature-priority.py`. The local complete list, scores, exact input hashes, source paths and coverage are written to ignored `outputs/creatures/frequency.json` and `frequency.html`. Rebuilding the creature board also refreshes the order and links it. Other facets can be audited with `--maps felucca trammel ilshenar malas tokuno termur --output outputs/creatures/frequency-all.json`; the current work order remains Trammel first.

The next model is the ordinary bird. A CC0 yellow-billed shrike by pistachio has been downloaded from [its author page](https://opengameart.org/content/bird-yellow-billed-shrike) and statically inventoried. It has a 996-triangle textured mesh and a 65-bone rig, but no supplied animation actions. Blender inspection disabled embedded script execution. It remains a source trial until authored action replacements, hues, terrain support, native behaviour and a static corpse are verified. Exact download URL, license and hashes are retained under ignored `work/birds/`.
