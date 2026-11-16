# Sentinel Spider and missing Abyss creatures

The shipped Ter Mur Underworld definition names Sentinel Spider alongside Wolf Spider. The project's creature extension now resolves the Sentinel by name. It uses body 157, hue 1141 and sound `0x388`. ModernUO supplies melee combat and Armor Ignore, and the existing Underworld Fortune service handles the 3% Lucky Coin chance. The form keeps the original Third Dawn Giant Black Widow rig because the Sentinel shares its body ID. The authoritative hue distinguishes the Sentinel in life and on its static corpse.

A disposable Ter Mur server loaded the shipped spawner through ModernUO's normal JSON and spawning code. It produced a Sentinel Spider within the configured home range with body 157 and hue 1141. Separate Classic and Enhanced client trials in a Trammel arena each passed 13 checks. The spider chose a native group 4 attack and damaged the target. Its normal death produced corpse graphic `0x2006` with body 157 and hue 1141. The client handed the fall off to a visible frozen mesh. The fixture provoked the attack with a stationary Ogre Lord and invoked the standard death method. The exact placed test exercised spawn placement. The client tests exercised appearance and combat in the arena. Armor Ignore was checked as the configured ability, and its chance and the Lucky Coin drop rate were not measured.

The body, hue, sounds and behaviour were checked against ServUO at commit `d76bf4443cf76d081ddaf8f57c87ff33749256af`. The reviewed Sentinel reference has Git blob `383157c64f518320468419d3561357fb7db7e6ea`. The project implements these behaviours with ModernUO's own creature, weapon and fortune APIs. The reference file and the official client payloads stay local. [Pinned Sentinel reference](https://github.com/ServUO/ServUO/blob/d76bf4443cf76d081ddaf8f57c87ff33749256af/Scripts/Mobiles/Normal/SentinelSpider.cs) · [Official Underworld guide](https://uo.com/wiki/ultima-online-wiki/world/dungeons/underworld/)

## References for the next creatures

The pinned ModernUO body table and independent character references agree on these five IDs. The official Enhanced 4.0.117.33 manifests identify the indexed groups in `AnimationFrame2.uop`. The existing AMOU decoder verified all of the groups listed below across five directions. An additional 780 Sentinel frames across 17 groups came from `AnimationFrame5.uop`. The local evidence records each member identifier, URL and SHA-256 digest.

| Creature | Body | Decoded groups / frames | 3D source status |
| --- | ---: | ---: | --- |
| Maddening Horror | 721 | 17 / 785 | No creature row in the checked Third Dawn tables. The reference shows a robed flayer with facial and lower-body tentacles. |
| Medusa | 728 | 17 / 820 | No creature row in the checked tables. The reference shows an upright archer with snake hair, shield and quiver. |
| Navrey Night-Eyes | 735 | 16 / 715 | Third Dawn uses this number for a shirt. The reference shows a giant dark spider with a swollen abdomen and long, thin legs. |
| Slasher of Veils | 741 | 17 / 1,105 | No creature row in the checked tables. The reference shows long claws, a tail, a ragged dark mantle and violet details. |
| Stygian Dragon | 826 | 20 / 1,360 | Third Dawn uses this number for a Forest Ostard. The reference shows a horned dark dragon with long red wing membranes and gold armour details. |

For Navrey, the existing Third Dawn spider rig is a candidate for a refit to the new silhouette and action timing. The later bosses still need their own visual fitting and their encounter-specific abilities. [Official Stygian Abyss notes](https://uo.com/wiki/ultima-online-wiki/technical/previous-publishes/2009-2/publish-60-8th-september-stygian-abyss/)
