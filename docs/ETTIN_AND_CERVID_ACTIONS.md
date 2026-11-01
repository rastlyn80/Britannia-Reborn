# Ettin and deer action review

This occurrence-first batch improves existing creatures rather than adding new body IDs. Native Ettin body **18**, Hind / EnragedHind **237**, and GreatHart / EnragedHart **234** retain their Third Dawn meshes, rigs, UVs and seven recovered core categories. Source-table Ettin body 2 remains compatibility only. Source geometry, generated local atlases, rig audits and all captures stay ignored; this commit supplies project code, recipes and evidence documentation.

## Exact source and declared replacements

The input archive has SHA-256 `d872d59a4d3f92c82672bbadb98ae44772e42b44dacb4a28a1fdf39cf121dc0e`. Exact mesh members:

| Model | Member below `uotdb/uotd/Models/` | Mesh SHA-256 | Bones / refined triangles |
|---|---|---|---|
| Ettin | `Monsters/ettins_ettin_lod2.grn` | `98964da5686c3c0a1808ad8fd74d02e4e2a2f1a2586734ad9e4667e474ca2413` | 33 / 7,520 |
| Hind | `Animals/deer_doe_lod2.grn` | `67ef5271f676a6e911d99951f473976c4b0193ed64596305bbe94996d0492096` | 33 / 2,656 |
| Great hart | `Animals/deer_stag_lod2.grn` | `00aff4173892276b66baf9154b942b8eb6bfc4f232bb9618df3c66e27297f92c` | 33 / 3,296 |

The archive contains only `idle`, `walk`, `run`, `attack1`, `gethit`, `die1` and `fidget` clips for these three stems. No alternate strike, cast, pillaging or grazing clip is recovered. Added clips below are explicitly authored replacements, not original choreography. Existing source clips, maps and rigs remain available in the comparison treatments. The Ettin's earlier bounded single-unweighted-vertex repair remains documented in local preparation; this batch does not replace that repair with invented source weights.

`creature-humanoid-actions.py` now supports the Ettin's three spine segments and two actual weighted head controls (`geosphere01` / `geosphere02`). It adds overhead and sweeping strikes, a cast and a crouch/reach Pillage category. Both heads retain their source separation and skin bindings; wrists, fingers and grasp attachments retain their local source hierarchy. A broad-boot stance correction distributes reach through the torso instead of forcing deep knee flexion that makes calf-weighted boot geometry penetrate the floor. The initial rendered probe caught a 12 cm ankle lift; the final pose preserves the tested stance tolerances. The seven source categories remain intact.

Native classic monster 5/6 reach the distinct new strikes; 12 / modern 11 reach Cast, and 11 / the explicit modern 14 category reach Pillage. Additional modern 2/5 categories retain the established Hit/Fidget interpretation used by the orc replacement. These are declared category mappings, not certification of every original mode/subaction. Pinned `Ettin.cs` enables `CanRummageCorpses`; this test exercises explicit packets, not an autonomous looting sequence. The ordinary Ettin is a melee actor; the Cast category supports explicit packets/polymorphed-player use, not a claim of ordinary NPC spell-AI animation.

`creature-cervid-actions.py` adds a grounded head/neck thrust for native animal group 6, alongside the preserved rearing source strike for group 5. It also supplies a distributed grazing action for group 3, replacing the generic runtime feeding approximation. Three-segment fore/rear legs use measured lengths, a FABRIK pass and an exact final two-link solve; hoof world orientations and targets remain anchored. Skull counter-rotation keeps forward antler tines clear while the muzzle lowers. Crouch magnitude depends on neck-pivot height, not total antler height. Both models' muzzle skin reaches approximately 44 / 52 mm above the support plane in the measured middle pose.

The stag's full antler height is now 2.0 m, while the doe remains 1.5 m. Previously equal total heights shrank the stag's torso and legs to accommodate its antlers. The new sizes retain approximately equal source-space body scale. No server statistics, native entity coordinates or movement rules are changed. The tiny original meshes still have coarse limb volumes; silhouettes, transitions and extended modes remain art/fidelity work rather than completed final art.

## Native identities and isolated fixture

Pinned `EnragedCreatures.cs` declares both enraged cervid classes with required `Mobile summoner` constructors. For an explicitly requested, allow-listed class, the disposable fixture supplies its living test owner only for that exact parameter on `BaseEnraged` descendants. Ordinary default selection still skips required-master constructors, preserving its previous class preference. No body or statistics are overwritten. The hook remains outside the server checkout and requires the existing isolated-test setting, loopback connection, test-account prefix and generated class/body allow-list. Production, real accounts and saves are untouched.

The deer fixture explicitly tests Hind, EnragedHind, GreatHart and EnragedHart, rather than selecting one default constructor or treating every declaration in their shared source file as tested. The local work board now lists positive **named body/constructor pairs** from passing reports separately from body coverage. It currently has 116 such pairs; older reports without class names remain body evidence only. There is no claimed complete constructor denominator or constructor-completion percentage.

## Evidence

All final focused checks pass:

- Eight synthetic humanoid checks, including three-spine/two-head stance/grip invariants, source immutability and distinct arm paths; four synthetic cervid checks cover measured segment lengths, all four hoof anchors, closed trajectories and antler-height independence.
- Ettin: **903 core checks / 273 skin samples**, **13 standard GPU checks / six views**, **1,194 gesture checks / 84 skin samples / 36 finite-plane cases / 20 captures**, and **158 actual disposable-server/two-client checks** for native body 18.
- Cervids: **1,371 core checks / 420 skin samples**, **25 standard GPU checks / 12 views**, **853 gesture checks / 52 skin samples / 36 finite-plane cases / 20 captures**, and **430 actual disposable-server/two-client checks** covering all four named native constructors on both test characters.
- Orc compatibility control: all four prepared GLTF files were compared against their previous recorded hashes and remain byte-identical. The shared helper's refreshed recipe receipts pass **3,637 core / 1,113 skin samples**, **49 standard GPU checks / 24 views** and **4,314 gesture checks / 336 skin samples / 144 finite-plane cases**.

The cervid test measures actual weighted muzzle and individual hoof-sole vertices, not only joint markers or the whole model's lowest point. It requires all four separate skinned contact records, flat soles within 25 mm, sampled finite-plane soles within 50 mm, fixed native coordinates and visible rendered gesture changes. The Ettin test separately confirms both head controls have real skin influence, retained head separation, original grasps/wrists and distinct strike paths. Acceptance rejects stale asset/import/runtime/recipe hashes or missing per-model phase/terrain samples.

Current exact-input evidence across **103 local forms / 38 groups** totals **71,456 pose checks / 21,567 skin samples** and **1,435 standard GPU checks / 618 views**. Unchanged families retain their matching prior receipts; the focused models and orc control above were rendered anew. All 38 families passed current receipt acceptance, and all **167 static corpse variants** passed **1,559 fresh rendered checks**. Full `scripts/verify.ps1` exits 0 with no script errors, 71 server-extension / 84 client developer-edit checks and a clean final world startup; existing Unicode/teardown diagnostics remain. Public dolphin motion and its isolated 16-check distribution test also pass in that run.

Primary final logs: `work/creatures/ettin-cervid-checks.log` (Ettin/orc; its earlier deer attempt failed), `cervid-grounded-checks.log`, `cervid-soles-final.log`, `ettin-actions-native-final.log`, `cervid-native-final.log`, `ettin-cervid-retained-evidence.log`, `ettin-cervid-corpses.log` and `ettin-cervid-full-verify-final.log`. The early failed grazing/stance probes remain local for audit; they are not final acceptance evidence. Current reports and images are under ignored `outputs/creatures/ettins/`, `deer/`, `orcs/` and `outputs/corpses/`.

## Reproduction and next work

```powershell
python -B scripts/prepare-creatures.py --families ettins deer orcs
./scripts/test-creatures.ps1 -Families @('ettins','deer','orcs') -Jobs 3 -Capture
./scripts/test-horses.ps1 -Live -SkipContact -CreatureFamily ettins
./scripts/test-horses.ps1 -Live -SkipContact -CreatureFamily deer
python -B scripts/build-creature-catalogue.py
python -B scripts/build-creature-actions.py
./scripts/verify.ps1
```

Native commands run sequentially on the disposable loopback 2594 server. PowerShell now rejects stray positional arguments: multiple families must be supplied as an actual array, preventing a purported multi-family run from silently testing only the first. Review controls expose the extra clips and label their shared motion as recovered plus authored, rather than calling every category a source clip.

Tested body coverage stays **135/279 (48.4%)**; generic connected slots reach **2,278/3,074 (74.1%, including reuse)**, with 796 still missing. Source forms, native identities, connected categories and final animation quality are distinct measures. Continue with ordinary Rat body 238, then Cat/Eagle and the configured occurrence queue. All creature families, original modes, source/terrain/shoreline/corpse-transition gaps and remaining native identities stay in scope.
