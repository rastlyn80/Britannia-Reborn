# Underworld goblin clans

The ordinary Green Goblin, Green Goblin Alchemist, and Green Goblin Scout are opponents of the Gray Goblin, Gray Goblin Mage, and Gray Goblin Keeper. They use ModernUO’s existing opposition groups with their distinct native classes and shared body 723. The Keeper retains hue 1900 and has its own corpse label.

The isolated trial placed the Green Goblin, Green Goblin Alchemist, and Gray Goblin Keeper on adjacent, walkable Ter Mur tiles. Both green goblins independently selected the gray keeper, the keeper selected a green goblin, and the keeper took damage. It started with 186 hit points and had 178 at the sampled combat state. Both clients received its native body and matching static corpse item. The fixture applied the final damage after the AI attack was observed. All 30 checks passed. This trial did not measure natural roaming or combat at the stock Underworld spawns.

The broad clan relationship is a reconstruction using the shipped region placements, the official Underworld guide, and the distinct tribal labels in the pinned emulator references. [Official Underworld guide](https://uo.com/wiki/ultima-online-wiki/world/dungeons/underworld/)

## Green Goblin Scout

The native Underworld spawn file configures the scout at Ter Mur `1034, 1028, −43`. The importer created the stock spawner with GUID `399bf1fe-0c47-4945-8c14-5ee8a1d3b6b3` and the trial obtained the scout through that spawner. The scout roamed, hid, and revealed a hidden player during native AI updates while the fixture observed it. The same scout and spawner serials persisted on restart, the behavior repeated, and both clients received the body 723 corpse through native graphic `0x2006`. The fixture applied the final damage. The trial passed 46 initial and 22 restart checks.

The scout reuses the goblin rig and retains the documented body, hue, and combat statistics. The ModernUO adaptation uses MeleeAI for unarmed combat and implements the reference scout’s hiding and retreat policies through native APIs. Hiding 100, Stealth 80, and Detect Hidden 80 supply the prerequisites needed for those APIs. These values and melee reach are local reconstruction choices. [Pinned scout definition](https://api.github.com/repos/ServUO/ServUO/git/blobs/cbdaee1df4f59c60d10b77d483e4d9ebe81fe233) · [Pinned scout AI](https://api.github.com/repos/ServUO/ServUO/git/blobs/7b9b25548bdd2cc1d348047a607c0fa7cda8216b)

A separate trial resumed a copy of the scout save and moved the scout and player to a clear stretch of Ter Mur. The client sent an ordinary attack and the observer sampled the native movement while combat was active. The scout retreated three tiles in one update. The trial passed 30 checks. The subsequent native drop trial includes the Scout. [Font of Fortune and corpse drops](UNDERWORLD_FORTUNE.md)
