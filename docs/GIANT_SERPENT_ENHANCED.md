# Giant Serpent Enhanced actions

The optional profile covers the original Third Dawn body 21. The native Giant Serpent, Death Adder and serpent-shaped Plague Spawn each retain their own server appearance and gameplay. The Silver Serpent stays on its separate original rig, atlas and renderer.

The official loose Enhanced archive supplied 660 registered frames in fifteen groups. The client retains the five earlier Enhanced fits, all Classic animation keys, and the original gait and recoil keys. It adds a raised-head combat slither and low peaceful idle. The selector uses the registered action and stance choices, including both original collapses. A new move can interrupt a standing fidget. Strikes and falls retain their playback. See the [animation reference ledger](../scripts/giant-serpent-enhanced-sequences.json).

Prepare the preceding optional Giant Serpent Enhanced scenes, then run `python -B scripts/prepare-giant-serpent-enhanced.py --install` and launch the Enhanced profile. This verifies the three preceding scenes, retains their tracks and installs three local additions under `Viewer/local-art/creatures/giant-serpent-enhanced`. The archive members, generated scenes and screenshots remain local.

The Classic and Enhanced client replays passed 11 and 115 checks. Terrain tests covered 7,803 fully skinned poses and 108 fall transfers, including a death while surfacing. The largest measured transfer displacement was 1.0 micrometre. Forward+ rendered 45 views across all fifteen groups. A fresh build reproduced the original and fitted animation keys, skeleton, skinned geometry and atlases across 1,731 animation tracks.

Two disposable ModernUO clients passed 129 checks across six constructor and character cases. The trial used the stock summon API for Death Adder and sampled the native Plague Spawn constructor for the serpent body. Native walk and run, raw and dyed hues, the weapon hit reaction, the death packet and the static native corpse passed. The explicit Enhanced actions were requested through the fixture.
