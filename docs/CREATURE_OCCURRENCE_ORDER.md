# Creature work follows world occurrence

Owner priority: work from the creatures encountered most often to the least common. The active client configuration selects Trammel, so its full native spawn definitions take precedence over alphabetical asset families. Reuse work across related forms where appropriate; retain specific blockers and continue the ordered list.

`scripts/build-creature-priority.py` reads the active era's shared and post-UOML Trammel definitions, the server class hierarchy, current body routes and native test receipts. It counts 2,137 configured spawners. The latest Trammel audit classifies 199 non-human mobile entries. Human NPCs and item spawns have separate classifications.

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

Quest, summoned, manually placed and other bodies absent from the direct spawn mapping remain in the full native body catalogue and the report's unmeasured-body section. Their frequency is unknown, not zero. They remain in scope after the measured occurrence order unless better census evidence changes their priority.

Rebuild with `python -B scripts/build-creature-priority.py`. The local list, scores, input hashes, source paths and coverage go to `outputs/creatures/frequency.json` and `frequency.html`. Rebuilding the creature board also refreshes the order and links it. The JSON field `next_native_evidence_gaps` lists configured types whose model routes lack a passing receipt in the catalogue's supported format. Other facets can be audited with `--maps felucca trammel ilshenar malas tokuno termur --output outputs/creatures/frequency-all.json`. The work order remains Trammel first.

The audit includes the project creature extension and its declared spawn aliases by default. Optional later-model routes require all three scene files to match the checked profile. A six-facet run against a disposable ModernUO server with the extension loaded matched all 535 configured names. It found 480 mobile names, including 77 supplied by the extension, plus 27 items and 28 unresolved names. Trammel accounted for 293 mobile names and 12 unresolved names. Orc Scout (181) and Crystal Hydra (265) each gained a Trammel occurrence in the catalogue. Name resolution verifies which type the server looks up. Actual constructor, combat and corpse tests have their own records. Use `--stock-only` for a server with only stock content, including when checking older stock-only reports with `--native-lookup`.

All 77 extension names also passed 16 calls each through ModernUO's default constructible path, for 1,232 successful samples. The sampled body IDs are recorded separately from client observations. With those samples, the six-facet report identifies 358 non-human entries. All identified bodies had a configured graphics route in the prepared workspace. That count covers resolved and sampled bodies and does not certify animation fidelity, equipment, spawn placement or corpse behaviour. The 28 unresolved names include Stygian Dragon, Slasher of Veils, Navrey Night-Eyes and Medusa.

The first route, ordinary bird body6, now has a distributable CC0 shrike mesh/rig/maps and authored categories, measured interaction/terrain support, raw hues, native behaviour and a static corpse. It passes2,068 motion checks,117 actual GPU presentation checks and102 isolated native-server/two-client checks. This is bounded integration, not final species anatomy or original choreography. [Sources, reproduction and remaining gaps](BIRDS.md). The orc's common action review now adds distinct strikes, casting and ground-slap categories with measured stance/grips and final native checks. [Orc evidence and remaining fidelity gaps](ORC_ACTIONS.md). Water elemental body 16 now has an independently distributable authored replacement, 547 GPU / 150 native / 13 clean-distribution checks and a static puddle. Its named source mesh remains absent from this archive; original particle bindings are unproven. [Water evidence and explicit shoreline/phase-handoff/fidelity gaps](WATER_ELEMENTAL.md). Kraken body 77 now has a preserved/refined source, restored alpha, local modern surface, authored strikes/cast, native-waterline anchoring and a static corpse. Both Kraken and Leviathan pass 246 actual two-client checks on genuine water; focused/core/shared verification passes. [Kraken evidence and remaining fidelity gaps](KRAKENS.md). The next missing routes are sea serpent/deep sea serpent and dolphin. Their source trials are prepared only; keep native class cases separate even when they share a graphic. Existing routes retain their outstanding original-action, anatomy and terrain reviews in the catalogue.
