# Air Elemental, Wisp, Ghoul and Gorilla terrain

| Body | Models and identities | Classic living poses | Enhanced living poses | Classic / Enhanced decoded corpse transfers |
| --- | --- | ---: | ---: | ---: |
| 13 | Air Elemental, Summoned Air Elemental, Crystal Vortex | 8,680 | 9,548 | 88 / 104 |
| 58 | Wisp, Crystal Wisp | 7,378 | Same public motion set | 64 / same public fall set |
| 153 | Original Ghoul and Bogle | 5,208 | 6,076 | 64 / 80 |
| 29 | Original Gorilla | 3,906 | 6,510 | 64 / 112 |

Air measures the visible skinned cloud and rigid dust separately. The split-tread cloud support leaves 28 mm for its maximum 25 mm vertex billow. Both collapse clips preserve the displayed shader phase and the cloud-to-dust timing. All living samples retained a visible cloud or dust surface. The persistent corpse freezes only the dust with the native hue. The summoned elemental sends the stock death packet, then its transient corpse is deleted. Two clients agreed on that packet and neither retained a static corpse. Air uses the independent public GPL cloud/dust and CC0 Quaternius carrier described in [Air Elementals](AIR_ELEMENTALS.md). The optional local Enhanced treatment adds Spread Alert and Vortex Formation.

The Wisp retains all eight surfaces of the existing seven-joint energy rig. The terrain path uses the full skin, including the outer rays, and the replicated corpse freezes all eight surfaces and their shared phase. See [Wisps](WISPS.md) for the public art and action provenance.

Ghoul and Bogle keep their Third Dawn body, atlas and existing original actions. Gorilla keeps its original rig, separate atlas and stomp. Its knuckles and both feet probe separate treads. Both original forms retain their optional Enhanced gestures. The native body and hue feed the same static corpse graphic 0x2006. When the Classic packet requests an alternate collapse for a rig with only the one source fall, the existing fallback remains the original fall. See [Third Dawn source members and hashes](GHOUL_GORILLA_HEADLESS.md).

## Reproduce

Run `scripts/verify.ps1` from the repository root. The occurrence tests drive the normal client, including the terrain renderer selected by World and the corpse handoff from a decoded death packet. The installed Classic source assets enable the original walking forms. The validated optional local manifest enables the additional Enhanced gestures. The public Air and Wisp scenes use the digests recorded in their distribution provenance.

The isolated ModernUO checks exercised stock constructors, movement, dyes, action packets and corpses using two clients. Air passed 122 Classic and 134 Enhanced checks across its three identities. Wisp passed 88 in each mode across its two identities. Ghoul and Bogle passed 84 Classic and 92 Enhanced, including Ghoul melee, Bogle Lightning and both fitted Enhanced gestures. Gorilla passed 50 checks per mode, including the stock wrestling and hurt packets and real Animal Taming through the player target cursor. The stock taming handler assigned the owner and one follower slot. Controlled packet emission provides the Enhanced gesture observations. Stock Air, Crystal Vortex, Wisp and Ghoul-family corpses retained the tested native hue.

The tested floor shapes were flat ground, a moderate slope and two finite treads 22 cm apart. At the tallest tread the largest single sampled vertical corrections were about 205 mm for Air Lie Down, 274 mm for the Ghoul attack and 223 mm for Gorilla Lie Down. These corrections clear the tested geometry and remain open for motion review. The animation coverage ledger is unchanged.
