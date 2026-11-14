# Lady Melisande

## Original client appearance

Body 258 resolves to LadyMelisande in the archived Mondain's Legacy 3D client. The installed Classic client routes it through Bodyconv.def to anim5.mul graphic 17. Thirteen Classic groups contain 280 frames. The Enhanced sequence is 0x3a09b183f15817af. The Third Dawn model table predates this body.

The preparation uses the original model's 300 source vertices, 582 triangles, 46-joint rig, caped atlas and 13 motion files. The cutout shader retains the original cape alpha and applies server hues. The original mesh and weights are preserved because subdividing the cape can exceed eight influences per vertex. Run reuses Walk at a higher cadence. Enhanced casting and gestures with no corresponding original 3D track reuse related source motions. Peace idle reuses the original Idle clip.

Use the local unshield extraction on the owned Mondain's Legacy client cabinets to obtain Client/Models.txt and the mesh, atlas and motions listed under body 258 in scripts/later-creature-inputs.json. Then run `python scripts/prepare-later-creatures.py --body 258 --legacy-source <extracted-directory> --classic <owned-classic-install> --sequence <reviewed-AnimationSequence.uop>`. The recipe checks the exact source members, Classic MUL spans and Enhanced sequence before writing the three local scenes and merging the registry entry.

The normal World replay passed 57 Classic and 571 Enhanced checks. Both deaths handed off to static graphic 0x2006 using the validated cape material. A focused terrain run sampled 5,208 full-skin poses across flat, sloped and stepped surfaces. The preview rendered 18 poses from the original model.

## Blighted Grove

The placement command PlaceBlightedGroveBasket installs the basket beside the Frightened Dryad on the current facet. Offering a valid Dryad's Blessing reserves the native boss at (6483, 947, 23) and grants a ten-minute Dryad's Curse. Using the Curse and accepting the prompt admits players at (6518, 946, 36). The controller follows the project's Citadel encounter pattern. The existing classic placement references supplied both coordinates. The four initial Enslaved Satyrs use their reference locations.

The latest isolated run passed 28 checks on first entry and 58 after restart. Both party members accepted their own admission prompts and reconnected in the lair after restart. The encounter timer returned both players and removed the guards. A fresh blessing reserved a new encounter and its key, and the stale key was rejected while still in the player's pack.

The test fixture set the boss's target and health windows, shortened the encounter deadline, and supplied the rare crystal directly. Two clients observed Melisande's heal and corpse. The target received the nausea message, and one reinforcement wave arrived below half health. The corpse held Diseased Bark, Eternally Corrupt Tree and her wine. Normal item and confirmation packets released the crystal into a bonded squirrel. The client received body 278 and hue 0x482.

Autonomous targeting, the combat penalties from nausea, remaining helper mechanics and parity with the current official encounter are open. The random crystal drop was excluded from the test. The separate [perch parrot trial](PERCH_PARROT.md) verified her parrot reward using native deaths. The native and client appearance tests were separate, and the reconstructed encounter is staged locally.

[Official Peerless guide](https://uo.com/wiki/ultima-online-wiki/gameplay/quests/peerless-quests/) · [Pinned boss](https://api.github.com/repos/ServUO/ServUO/git/blobs/ae226eb017f4059690167dcdbcbb8c0d3938cbff) · [Pinned altar](https://api.github.com/repos/ServUO/ServUO/git/blobs/4d117163345b07303a7509f1610fd3e509d39a6c)
