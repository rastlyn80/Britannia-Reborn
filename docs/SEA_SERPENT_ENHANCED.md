# Sea Serpent Enhanced actions

Sea Serpent and Deep Sea Serpent both use native body 150 and keep their distinct constructor hues. Third Dawn's model table names `sea_serpents_sea_serpent` for both body 150 at scale 0.8 and artwork ID 145 at scale 1.0. The official Enhanced archive supplies 690 frames in fourteen indexed groups under 145. The fitting uses those references on the already validated Third Dawn rig for body 150. The separate client artwork route for 145 remains available.

The optional profile adds twelve fitted clips and retains the original walk and run. It keeps all of the Classic clip keys. Peaceful and combat swimming, the snap and diving strike, recoil, alert and two falls have separate routing. The aquatic rig keeps its waterline when a seabed or deck is within range. Native graphic `0x2006` displays a static corpse at the waterline, with the selected fall and any later hue update preserved.

With the local Classic Sea Serpent scenes already prepared, run `python -B scripts/prepare-sea-serpent-enhanced.py --install` and launch the prepared Enhanced profile. The build checks the three Classic scenes against their local bake and validates the generated scene hashes. The [reference ledger](../scripts/sea-serpent-enhanced-sequences.json) records the frame members and fit choices. Source frames, scenes and review images stay local.

The Classic and Enhanced client replays passed six and 48 checks. A full-skin test covered 1,764 poses over a finite seabed and deck. Forward+ rendered 42 sampled poses. An independent rebuild reproduced the geometry, material textures, skeleton and 2,433 animation tracks across all three treatments.

Two disposable ModernUO clients passed 75 checks across the two native constructors and both character rigs. The trial verified swimmer-only terrain, native movement, full and partial hues, stock hit and death packets, and the rendered static corpse. The fixture selected the test area and supplied the explicit Enhanced recoil and cast packets.
