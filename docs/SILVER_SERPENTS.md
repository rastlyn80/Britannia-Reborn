# Original Silver Serpent

Native SilverSerpent 92 retains its own later Third Dawn/Age of Shadows mesh, UVs, 64-square atlas, eighteen-joint rig and table scale 1.3. The source has 118 points / 237 triangles; the private refined mesh has 3,792 triangles. Table bodies 91/93 use the same model but have no named native constructor in this audit; they are compatibility routes, separately checked as static corpses. They do not add two native-body completions.

The later table explicitly links all three bodies to Giant Serpent 21 motions. Exact geometry, weights, hierarchy, weighted ancestor transforms and joint names are checked before sharing those motions. One unweighted scene label differs; each variant keeps its own UVs and atlas. Bind normalization and bounded smoothing are conversion steps, not a reconstruction of original-client affine skinning.

## Motions and support

Eight original motions are retained: Idle, Walk, Run, Attack, Hit, Death, Fidget and Pillage. Eat is an explicitly authored source-rig feeding bend; LieDown is the existing static-rest category. Attack retains the original jaw channels, with a measured maximum excursion of 50.607 degrees. The Ice Serpent's separate jaw constraint is not inherited. Newer protocol types 2/5/14 select Hit/Fidget/Pillage; classic monster groups retain their normal mapping.

The raw imported death skin missed the floor by 11.764 mm in a private off-grid probe. Current saved imports are measured at 960 Hz, and the presenter samples a scalar complete-skin correction. It changes the visual model's vertical offset, preserving the native entity coordinates and relative source joint transforms. Temporary mixed poses use a cached set of unique position/weight tuples. The weighted picking/nameplate bounds remain conservative across source motion. No foot chains are invented for this legless model.

Imports use 240 Hz, no key optimization/compression and uncompressed meshes. Modern and rounded geometry, skin bindings, transforms, buffers and animation data must be identical; the modern treatment changes the surface. Steady source actions, mixed poses and actual finite collider planes have separate evidence. Physical no-slip, arbitrary terrain and complete all-phase transition correctness remain unproved.

## Texture, cutouts and colour

The private 1,254-square atlas was made with the built-in image-generation edit tool from the original 64-square atlas. Its exact hash is `2a39fb4ee47e7cfeadcfca33f4e86d4661978e5451537675838fa991de64a086`; the exact prompt and source hash are pinned in `scripts/source-silver-serpent-inputs.json`. Fine scales, authored microrelief and restrained nonmetallic reflectance improve the old surface. Relief is an approximation, not a recovered normal map.

Generation introduced red eyes absent from the original. The material maps those head-region red texels to charcoal while keeping the mouth red. This is an authored colour correction, not spatial eye registration. The generated mouth/eye landmarks are not claimed to match the original pixels exactly; final feature placement and art quality remain open.

Original opacity is bound separately and remains unwarped, including all 318 original nonopaque texels. Partial hue classification uses the original atlas's neutral colour region rather than generated RGB. The saturation threshold is an authored interpretation, not recovery of an original `_m` mask. Raw full/partial hue bits and palettes remain intact without replacing the rig. Static corpses use the same original cutouts and material; the shader has no time-driven effect.

The first head-material probe used an idle head location for a moving strike and failed. The corrected probe targets the actual posed head. Explicit material parameters also make their runtime binding inspectable. Failed diagnostics remain private. A previous private atlas diagnostic incorrectly read compressed GPU image data; it is excluded. The corrected diagnostic decodes exact PNG bytes, independently establishing the 64-square source and its 318 nonopaque texels.

## Exact inputs and publication boundary

The preservation source is [uoaos.zip](https://zuluarchive.com/static/files/uoaos.zip), listed by the [Zulu archive](https://zuluarchive.com/pages/files.html). It is a third-party preserved input, not proof of official authenticity or a redistribution licence. No downloaded game executable was run. Thirteen original source members and these cabinets are pinned:

| Cabinet | Bytes | SHA-256 |
|---|---:|---|
| `client7.cab` | 20,805 | `8180b7c2b7cb4ca6e868a3ff460e25c0e6aa710367b8d5487d2d455bfef29859` |
| `client11.cab` | 35,160,963 | `307a6b91c4d5459080d1fe8a74ae4fe0b91dea8a21a2866ca91e7dc7ba92f1a8` |
| `client10.cab` | 33,956,665 | `92e9b23c0c226a0d20af5402af7624b188d3bf6e1c4adb510c9d0575d2daa1d9` |

The bounded ZIP/CAB evidence supplies no whole-ZIP hash or publisher signature. Original files, derived meshes/maps, generated atlas, prompts stored with private art, screenshots and local evidence remain excluded from Git. The prompt hash and source/hash metadata are published with the owned conversion/presentation/test code. This does not make the derived artwork independently licensed or available in a clean client download.

## Verified evidence

Private reports are under `outputs/creatures/silver_serpents/`; logs, failed probes and publication receipts are under `work/creatures/silver-serpent/`.

- Source actions: 5,657 checks / 1,110 skins / 740 paired poses across all ten source/feeding/rest categories. Relative source joint, basis and same-phase segment errors are zero; maximum grounded error is 0.155 mm. Twenty-four native timing/restart cases pass. Original Attack rotations remain unamended.
- Actual Forward+: 4,784 checks / 660 finite-plane poses. Complete skin clearance, source head motion, weighted nameplates and actual mobile picking colliders pass on raised/lowered flat/sloped ground. Full/partial difference is 2,977 sampled pixels; original cutouts affect 409, eye colour correction 367, detailed RGB 35,325 and relief 9,183. Nine body/hue corpse cases pass.
- Mixed motion: 31,400 checks / 9,500 flat mixed skins / 1,440 finite-plane mixed skins, including Run-to-Pillage and Run-to-Death. Five playback rates and two frame steps are sampled. Temporary support caches 1,849 unique points from 11,376 source vertices and measures about 0.37 ms per evaluation on this host; this is not whole-game performance certification.
- General validation: 718 checks / 210 skins. Standard GPU validation: fourteen checks / six views. Sixteen fresh original/refined/modern comparison frames are private.
- Real native constructor/actions/movement/death: 148 two-client checks, with exact SilverSerpent 92 on both disposable owners. Decoded owner/observer packets select the intended categories on both actual avatars. Raw hues, native Move, original Pillage and static corpse replication pass. Fixture-controlled NPC Move is not autonomous combat or player movement evidence.
- Native behaviour: 56 checks across both owners. Real double-click and target packets reach the private native DeathAdderCharmTarget. No-familiar, non-mobile-item and already-combating refusals pass; a valid target assigns the native Combatant and AI combat action. A real summoned/controlled DeathAdder replicates to both clients. Native post-melee callbacks apply lethal poison (three callback attempts per case in this run), and native immunity rejects lethal poisoning. Poison resistance, charmability and native allegiance getters are retained.

Native familiar creation uses `BaseCreature.Summon`; table registration and temporary player unblessing are explicit fixture setup, restored on cleanup. This does not certify a complete Necromancy summon spell or progression. Actors/AI are frozen for controlled sampling. Invoking the native post-melee callback does not prove a successful weapon swing or measured proc probability. Allegiance getters do not certify faction/ethics gameplay. Autonomous combat, loot/persistence, full choreography and final art remain open. The guarded fixture operates only in the disposable loopback 2594 world; production 2593/accounts/saves and original installations are preserved.

All 51 accepted local groups / 122 forms pass exact gates: 87,363 general checks / 26,460 skins and 1,668 standard GPU checks / 732 views. Unchanged evidence is reused only after exact input checks. All 200 corpse variants pass 1,881 fresh rendered checks. Full `scripts/verify.ps1` exits 0, including 71 server-extension / 84 developer-edit tests and clean final world startup; existing Unicode/teardown diagnostics remain.

Bounded native-body coverage is 165/279 (59.1%); 163 positive named body/constructor pairs have no complete class denominator. There are 122 local plus twelve independent public forms: 134 generic records / 162 routes and 2,923/3,888 connected slots (75.2%, including reuse), with 965 missing. Original metadata inference remains 802/3,003, separate from specialized humans/mounts. These are integration metrics, not final choreography, art or full native-gameplay completion.

## Reproduction

Keep exact private cabinets and generated atlas/prompt at the manifest's paths. Source preparation and local acceptance are separate. Changing art, imports or owned runtime code invalidates dependent evidence.

```powershell
python -B scripts/prepare-source-silver-serpent.py --check-inputs --extract --prepare
$godot = (Get-ChildItem .tools/godot/*console.exe | Select-Object -First 1).FullName
$env:APPDATA = Join-Path $PWD '.godot-user'
$env:LOCALAPPDATA = $env:APPDATA
& $godot --headless --path Viewer --editor --import
python -B scripts/configure-creature-imports.py silver_serpents
& $godot --headless --path Viewer --editor --import
& $godot --headless --path Viewer --script res://Presentation/BakeSourceSilverSerpentGround.gd
python -B scripts/prepare-source-silver-serpent.py --finalize-ground
./scripts/test-creatures.ps1 -Families silver_serpents -Capture -Live
python -B scripts/check-source-silver-serpent.py --native
python -B scripts/build-creature-catalogue.py
python -B scripts/build-creature-actions.py
./scripts/verify.ps1
```

The live driver creates a new isolated runtime and refuses an occupied port. It never attaches to or stops an unknown server. Publication includes only verified owned code/docs and provenance pins; concurrent terrain/building/UI work and private game-derived assets remain outside this change.
