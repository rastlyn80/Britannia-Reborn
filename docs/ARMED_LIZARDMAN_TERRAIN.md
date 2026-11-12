# Armed Lizardman living terrain

ModernUO selects either body 35 with a spear or body 36 with a mace. The client retains both original Third Dawn weapon meshes and their fitted grip. The server's Lizardman fights with stock wrestling, so the visual weapon follows the body ID. [Weapon and Classic motion sources](RATMEN_AND_LIZARDMEN.md)

The Enhanced archive audit found no direct named sequence or frame member for either armed body. The existing Classic clips and weapon binds supply the motions. The client aligns the rig to a shared support plane and solves the skinned soles against it. At a split level, individual surface samples guide the feet, tail and spear. The resulting adjustment affects the rendered model and keeps the server coordinates fixed. An idle fidget yields when the creature starts moving. Attacks retain their normal duration.

## Reproduce

Prepare and activate both Classic armed Lizardman scenes as described in the source document. The normal World selects the terrain renderer for each of the two known body and scene combinations. With the scenes prepared, run `./scripts/verify.ps1`. The two focused tests are `scripts/test-lizard-living-terrain.gd` and `scripts/test-lizard-living-steps.gd`.

## Evidence

The previous renderer let the body penetrate a sampled slope by up to 171 mm and the spear tip by up to 13 mm. The updated renderer passed 3,672 living poses on a flat floor and two slopes. Both body and weapon cleared the tested surfaces, with less than 1.1 mm of whole-model lift. Across 1,728 living poses on a 22 cm step, the worst measured clearance was 2.99 mm and the largest whole-model lift was 9.86 mm. Six Forward+ views exercised the actual modifier. The retained motion and corpse checks passed 1,220 decoded armed poses and 588 collapse poses, with both static weapons checked at three hues.

Two isolated clients passed 74 checks across both constructor bodies and both player sexes. The trial covered actual walk and run packets, native partial hue, stock wrestling and recoil, death and the corresponding static corpse. Native Rummage refused the protected fresh corpse. After the fixture aged the corpse past the two-minute protection window, Rummage moved the test item to the Lizardman's pack and both clients received the native emote. An explicitly sent Classic group 11 packet separately verified the existing Pillage clip.
