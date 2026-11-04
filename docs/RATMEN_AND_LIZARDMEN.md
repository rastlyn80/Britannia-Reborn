# Ratman and lizardman source forms

Two original Third Dawn forms now have bounded geometry refinement, generated UV-compatible surface atlases, source/category actions, raw native hues and automatic static corpses. Ratman has four historical body routes (42,44,45,142); lizardman has three (33,35,36). Native constructor evidence covers ratman42/142 and lizardman35/36. Historical44/45/33 are not counted as additional native-tested identities.

Lizardman's original alpha mask preserves the separate dorsal spines and tooth gaps instead of a solid fin sheet. Ratman's tooth/ornament cutouts are much smaller: six GPU views show2-7 removed pixels, about0.07%-0.22% of projected area. Their fine-edge policy requires real nonzero mask response; larger wing/frill cutout policies retain their stronger area requirements. Exact source mask hashes are included in acceptance evidence.

New bounded checks: ratman677 pose checks/189 skin samples, lizardman658/189; each20 actual Forward+ checks/6 views and16 comparison frames; each166 disposable-server/two-client checks, all zero failures. Candidate corpses pass31 and24 checks respectively. Original choreography gaps, anatomy and arbitrary terrain remain separate from these integration checks.

Reproduce using the existing local source inputs with `python -B scripts/prepare-creatures.py --families rat lizard --skip-index`, followed by `./scripts/test-creatures.ps1 -Families rat,lizard -Capture`. The rat shaman is an unaccepted source trial: its atlas generation was rejected by the image tool, its original surface is retained, and the local preparation record explicitly defers it. Reapply that deferred status after a full rat-family preparation; do not count it as an upgraded form. Native checks use `./scripts/test-horses.ps1 -Live -SkipContact -CreatureFamily rat` and then `lizard`, sequentially on the approved disposable loopback runtime.

All original source inputs, derived art, exact prompts, IR, receipts and captures remain local/ignored. The images were generated with the built-in tool and copied into `Viewer/local-art/creatures/`; their exact prompt files are listed by the local creature board. The source archive is unchanged.

## Armed Lizardman fitting trial

Classic directional frames for body 35 show a spear; body 36 shows a mace. Third Dawn stores the matching rigid weapon meshes separately under `Client/Models/Others` as `Weapon_Lizard_Man_Spear_Lod2.grn` (16 source vertices, 28 triangles) and `Weapon_Lizard_Man_Mace_Lod2.grn` (47 vertices, 90 triangles). Both reference `Client/Models/Maps/Weapons_512b.tga`. Exact input hashes are pinned in `scripts/prepare-lizardman-weapons.py`. Run it with the local extracted `Client/Models` directory to recreate the ignored atlas and triangle data.

Local trial scenes use the existing right-hand bone for both weapons. Five Forward+ captures per body cover the authored slot-11 stoop. The spear needs clearance from the tail, and both forms still need grip, locomotion, attacks and corpse checks before activation. The active shared Lizardman model is unchanged.
