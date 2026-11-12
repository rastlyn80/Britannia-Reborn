# Chicken: independent source, original motions and native body208

## Terrain and native corpse update

The regular client uses the terrain-aware hen with the checked public mesh and distinct-action library or the checked Enhanced scene. Both the body and eyes take part in surface clearance and the frozen corpse. The existing feather material, two Classic falls, and three fitted Enhanced gestures remain available.

The original presentation clipped up to 219 mm into the sampled 22 cm tread. The new support keeps the minimum visible clearance near 3 mm through 4,774 Classic and 6,076 Enhanced moving poses. The fastest tested run still has a visible 136 mm model lift in a sampled interval. The 72 Classic and 96 Enhanced decoded corpse transfers start from the displayed pose, including the live gestures and both collapse directions.

The normal client and isolated stock server passed 35 Classic and 41 Enhanced checks across both owners. The tests covered the real hen constructor and hue, walking and running, a fidget interrupted by movement, the distinct rear strike and the frozen native corpse. The three Enhanced gestures were sent through controlled protocol packets. Reproduce the occurrence world, terrain and fall checks with `--body=208`. Add `--enhanced-creature-actions` for the second profile.

The replacement is a natural hen from CDmir / Čestmír Dammer, with the artist's feather albedo/normal maps and source motions. It is an independently licensed substitute, not a recovered Ultima Online Chicken mesh or original UO choreography. Native identity, gameplay, hues and corpse packets remain authoritative on ModernUO.

## Source, licence and reproducibility

- Author submission: https://lpc.opengameart.org/content/chicken-animated
- Archive: https://lpc.opengameart.org/sites/default/files/chicken_0.zip
- Archive size6,214,921 bytes; SHA-256 `0e958040fdb855c192903657d8a9da2d95cf17ea23165676bae2ae1454baa284`.
- Included notice explicitly says CC0 and credits Čestmír Dammer, the Kelgar project, and UV texture derived from Rick Hoppmann photographs. Exact notice, archive/member hashes and source URL are retained in `scripts/chicken-inputs.json` and public provenance/NOTICE.

Static extraction checks each pinned member and keeps inputs under ignored `work/creatures/chicken/source`. Trusted Blender opens the source with `use_scripts=False`, factory startup and disabled automatic execution. The selected render components are Chicken and Eyes. The separate untextured Cylinder, lamps and camera are excluded explicitly; Cylinder's original intended role is not certified. The conversion preserves source points, UVs, materials/maps and forty source joints, triangulates faces, assigns matte PBR materials and corrects the separate comb/eye colours. The normal map remains the artist's map; it is not a generated replacement.

Two source bones use curved B-Bone segments. A normal forty-joint export preserves bone centres but loses up to58mm of surface deformation. `scripts/chicken-bbone.py` expands those two curved bones into seven ordinary segment joints with the original interpolated weights. Full segment rest matrices include scale; the conversion reconciles them with the actual rigid edit-bone rests. Original hierarchy/joints remain, with47 total joints. No remeshing or generic humanoid retargeting is used.

The separately evaluated original Blender mesh is the reference, not the candidate's own skinning code.187 complete imported source poses match within0.506mm in absolute/relative surface position, including the head/neck and back curvature. Restoring omitted constant Grounding tracks removes a separate1.94mm shared-root offset and prevents floor values leaking between actions. The largest sampled penetration is0.151mm before terrain support. This is a finite sampled comparison, not a bound over every continuous time.

The original source has eleven moving clips, all retained as Source-prefixed diagnostics: BeginPecking, Dying, Eating, EndPecking, Idle, Idle1, Idle2, Pecking1, Pecking2, Pecking3 and Walk. Two single-frame source actions, Stand and StopPecking, are not exported as separate moving clips. The source archive remains pinned for reproduction. The public GLB includes all eleven moving clips plus eight active categories.

## Active actions and native appearance

| Category | Conversion |
| --- | --- |
| Idle | Retained short Idle2 cycle |
| Walk | Retained Walk poses, declared timing and measured stance reference |
| Run | Authored running bound using retained Walk joint poses,25mm positive lift and a measured bounded shared-root contact/reset curve |
| Attack | Authored0.64s beak strike assembled from original lowering, Pecking3 and recovery, whose source boundary poses match |
| Hit | Authored35mm backward/6mm upward recoil; relative original joint poses retained |
| Death | Retained source Dying pose sequence |
| Fidget | Retained looping Idle1 cycle |
| Eat | Retained source Eating cycle |

Source Walk is slow: approximately0.101m/s median backward toe-landmark speed over2.208333s. The active0.4s Walk uses measured reference0.55859m/s. Run uses0.8s, reference2.7m/s,25mm positive lift and shared longitudinal offsets between approximately-102mm and+113mm. Native1.8/6.8m/s selects rates around3.22/2.52 without clamping. Running contact landmarks follow native travel in the tested intervals; this is not a no-slip physics simulation or recovered UO timing. Entity coordinates and native flying state are unchanged.

The source's two independent foot-control roots and seven new segment roots remain intact. Finite-plane support tilts/translates the visual without inventing conventional leg chains or flattening positive source/authored lift. Cached positive bone-influence boxes cover both actual body and eye meshes, and update selection/nameplate bounds for each pose.

The shared `HumanAvatar` selection update now changes the box size as well as its centre. Previously a body with dynamic pose bounds retained its spawn-time collider size. The actual world-space collider is checked against all weighted vertices over192 finite-plane poses, and the public standalone test also checks resizing across every saved category. Human/mounted selection branches remain guarded separately.

Native208 is animal-profile Chicken. Full and partial hue flags retain their exact values; an authored textured-body partial region preserves distinct comb/feature colour, while the original dark eyes remain protected. This is not a recovered native partial mask. Source albedo/normal textures remain bound; matte coat roughness is constrained to0.65–0.95. The normal map changes6,324 sampled lit pixels in the focused appearance check.

Native graphic0x2006/amount208 corpses freeze the actual last source Death skin, preserve hue/facing and both original components, retain UVs/materials, remove live skeleton/skin arrays and sit on their measured lower surface. They enter the common graphics-ID/corpse catalogue automatically.

## Focused evidence

| Gate | Current result |
| --- | --- |
| Independent original-source full-surface comparison |187 complete skins; maximum0.506mm; zero failures |
| Saved/imported source and active motions, loops, floor resets and gait landmarks |1,685 checks /627 complete skins plus187 paired source comparisons; zero failures |
| Actual public Forward+ avatar, colours, normal maps, picking, terrain and corpse |1,176 checks /192 finite-plane poses; zero failures |
| Real native Chicken constructor on both disposable owners |112 checks; zero failures, repeated on installed public art |
| Standalone public package with actual avatar/picking/skins/corpses |736 checks /171 complete skins; zero failures, starting from only the model, import settings and notices/provenance; no donor files, external source maps, private art, game data or server |

AI is frozen for controlled native sampling. These are actual native world-entry/movement/action/death tests, not offline fixture movement called multiplayer. Autonomous AI, taming/combat behaviour and full gameplay are not certified. Production runtime/accounts/saves are excluded. No server core/gameplay source was edited.

Current receipts are under `outputs/creatures/chicken-trial/` and `outputs/creatures/chickens/live.json`; logs are under `work/creatures/chicken/`. All43 accepted local groups/109 forms pass75,826 pose checks/22,911 complete skins and1,512 fresh standard GPU checks/654 views plus focused gates. All183 corpse variants pass1,724 rendered checks. Full `scripts/verify.ps1` exits0 with71 server-extension and84 developer-edit tests and clean final world startup. Existing Unicode/teardown diagnostics and two nullable warnings in unchanged PreviewTools tests remain. The subsequent author-notice encoding correction changes no model/runtime bytes; current independent source, public GPU/native/clean-distribution and all four public acceptance gates were rerun successfully.

The standalone runner copies only five published files into its fresh project: `chicken.glb`, its precision import settings, `NOTICE.txt`, `SOURCE-LICENSE.txt` and `provenance.json`. The original two CC0 maps are embedded in the GLB. Godot regenerates extracted PNGs/import caches itself; those duplicate generated files are excluded from this publication. The exact original UTF-8 licence is checked against its archive member hash by the public acceptance gate.

## Reproduce

1. `python scripts/prepare-chicken.py --inputs` obtains/verifies the exact independent archive and statically extracts only pinned members. The licence/source archive is not an executable.
2. Run trusted Blender with `--background --factory-startup --disable-autoexec --python-exit-code 1 --python scripts/blender-prepare-chicken.py`. This full source bake includes the49.375s Idle and can take several minutes.
3. Import Viewer, run `python scripts/prepare-chicken.py --configure-imports`, and reimport. Source/modern imports use240Hz, uncompressed meshes and disabled animation reduction/compression.
4. Run `ChickenSourceGait.gd`, then `python scripts/creature-chicken-actions.py --source Viewer/local-art/chicken/chicken-source.glb --preparation Viewer/local-art/chicken/preparation.json --gait outputs/creatures/chicken-trial/source-gait.json --output Viewer/local-art/chicken/chicken-modern.glb`. Reimport/configure/reimport the modern output.
5. Run `ChickenMotionTests.gd`; generate the independent reference with trusted Blender and `scripts/blender-reference-chicken.py`; run `ChickenSourceTests.gd` and `python scripts/check-chicken-source.py`. These are actual saved skins compared with the original source deformer.
6. `python scripts/prepare-chicken.py --candidate`; run `ChickenPresentationTests.gd`; stage with `--stage`; run `scripts/test-horses.ps1 -Live -SkipContact -CreatureFamily chickens` against the disposable loopback server.
7. `--install` copies only the independently licensed public model/provenance/NOTICE. Configure/import its precision, repeat `ChickenPresentationTests.gd -- --public` and the native test, then run `scripts/test-chicken-distribution.py` and `prepare-chicken.py --verify-public`.
8. Run current shared/public controls, every accepted local source group, the rendered corpse catalogue and `scripts/verify.ps1` before publication. Ship original project code and independently licensed public assets; retain all proprietary/source-derived UO inputs and local captures outside Git.

Remaining scope includes all other native identities/families, original per-class choreography, arbitrary terrain, complete original masks and final visual polish. Chicken's independent substitute does not recover the absent original UO artwork.
