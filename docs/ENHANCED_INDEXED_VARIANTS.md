# Enhanced action variants for the remaining indexed bodies

The prepared client uses 31 original sprite records from Enhanced Client 4.0.117.33 as references. The references contain 2,035 frames in five directions. The input manifest records every archive member and its SHA-256, and records the exact Enhanced action tables.

| Body | Appearance and motion |
| --- | --- |
| 692 Animated Weapon | Reconstructs the shaft direction and centre from five views of its sweep, recoil, rise, spin and collapse. It retains the archived Third Dawn halberd as a donor. The shaft fit measured 1.87Ã¢â‚¬â€œ2.89 pixels RMS. Roll around the shaft is inferred. The stock summon leaves no persistent corpse. |
| 705 Stone Form | Retains the Third Dawn Earth Elemental donor and earlier Classic motions. Enhanced selects a backhand or overhead strike by attack subaction and variation, and selects the backward or forward fall in archive order. |
| 831 Parrot | Retains the original Third Dawn rig. The three fits are a falling tuck, raised-wing recoil and resting crouch. The second source choice for action type 3 selects the resting crouch on a living actor. A stock death packet independently starts a collapse. |
| 1246 and 1247 Pumpkin Head | Both use Karolina RenkiewiczÃ¢â‚¬â„¢s CC-BY-4.0 Pumpkin LP with the projectÃ¢â‚¬â„¢s authored flame and mask. Both have distinct ignition and collapse motion. The blue variant has its own cast plume. The static corpse retains the gourd, with the native hue. |

The combined Enhanced tests replayed 20,610 selections and state checks across these five bodies. Individual tests also covered 121 Classic checks, 4,447 terrain poses and 56 fitted fall handoffs for the Parrot, Stone Form and Animated Weapon. The two Pumpkin Head variants also passed six standalone corpse hue checks. The Enhanced action tests are decoded packet replays. Native constructor and summon behavior have separate evidence.

## Native Spellweaving

An isolated ModernUO test logged in two clients and attempted both normal Spellweaving casts. The server refused Summon Fey with cliloc 1074563 and Summon Fiend with cliloc 1074564 while their respective quest flags were absent. After the fixture set those flags, the same client casts produced Arcane Fey body 128 and Arcane Fiend body 74. Each used hue 0 and one follower slot. A controlled lethal test released the slot and both clients received the native corpse with the matching body and hue. Both corpses passed the projectÃ¢â‚¬â„¢s static renderer. The session passed 61 checks. The quest chains and autonomous summon combat remain outside this test.

## Rebuild and check

1. Extract the 31 named members of the matching Enhanced archives into a private folder as `ec-frame-BODY-GROUP.bin`. Check the sequence and the decoded frame identities with `python -B scripts/check-enhanced-indexed-references.py --sequence <AnimationSequence.uop> --frames <frame-folder>`.
2. Set `BR_INDEXED_BAKE_DIRECTORY` to the absolute path of a private output folder. Run `python -B scripts/fit-enhanced-halberd-indexed.py --frames <frame-folder> --output <output-folder>/animated-weapon-variants/fit.json` to reconstruct the donor halberdâ€™s motion.
3. From a checkout with the reviewed base creature art installed, run Godot with `--headless --path Viewer --script res://../scripts/bake-enhanced-<family>-indexed.gd` for each of `halberd`, `parrot`, `stone` and `pumpkin`. Every baker compares its earlier animation keys with the registered source scene.
4. Run `python -B scripts/prepare-enhanced-indexed-profile.py --baked <output-folder> --output-viewer Viewer` to install this optional profile locally. The SHA-256 checks bind each fitted scene to its reviewed base registration. The profile, generated scenes, decoded frames and screenshots remain local.
5. Replay `test-parrot-world.gd`, `test-animated-weapon-world.gd`, `test-stone-form-world.gd` and `test-pumpkin-head-world.gd` with `--world=res://world.json`, once with `--enhanced-creature-actions` and once in Classic mode. The fallback fidgets can be checked with `test-indexed-enhanced-world.gd` and `test-enhanced-fidget-dispatch.gd -- --installed`.

## Witch Apprentice quest

A two-client isolated test staged the completed imp hunt and placed the normal Magic Flute in the owner’s backpack. The regular double-click request triggered the real quest objective. Both clients received Zeefzorpul as body 74, hue 0, through the existing imp renderer. Both saw the stock removal, and the owner received recipe message 1055062. The timed disappearance left no corpse. The test passed 19 checks. The second quest branch passed 24 checks with the ordinary progress timer. Both clients saw the paper-theft encounter and separate body 400 apprentice corpse, with its native skin hue in the static renderer. The imp timed out while the corpse stayed in place. The owner opened the real corpse item, and both clients received its removal.

## Native familiar behavior

A real Necromancy familiar cast selected Dark Wolf body 99 with hue 0x901. In three samples its owner reached 26, 28 and 30 stamina while the nearby observer reached 25, 26 and 27 from the same starting value. The wolf’s native AI ran throughout. The 37 checks also covered both appearance packets and the owner’s normal release action.

An isolated 42-check Ethics trial staged eligible faction membership and a nearby ankh. The clients spoke the real oaths and the normal invocation. Each power spent five points and used one follower slot. Holy Familiar used body 100 and Unholy Familiar used body 99. Both retained their separate identities and the test dye on their stock corpses, and both rendered those corpses as static meshes.

## Unholy Bone and spawn lookup

In a 20-check isolated trial, both clients saw 24 stock Unholy Bone items and their removal as the ordinary hatch timers expired. The random branch produced Bogle body 153 in its existing Third Dawn renderer. This verifies the bone’s timed route to Bogle. The other random branches and carving remain separate.

A fresh lookup against the pinned compiled server resolved zero of the 105 names missing from the six-facet spawn catalogue. The local work order starts with Acid Slug, Wolf Spider and Chicken Lizard by estimated configured capacity. Each needs an authoritative identity before it can be connected to a client model.
