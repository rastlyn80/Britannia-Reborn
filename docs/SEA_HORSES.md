# SeaHorse native identity and documented horse-art fallback

SeaHorse is a real pinned ModernUO `BaseMount`: mobile body **144 / 0x90**, ridden item **0x3EB3**. Its constructor assigns these IDs without enabling swimming. Runtime tests confirm `CanSwim=false`, `CantWalk=false`, `Tamable=false`. Controlled ownership is disposable test setup; normal mount permission checks still run. This implementation supplies the installed client's documented horse-art fallback, not recovered Third Dawn SeaHorse geometry or new water-riding gameplay.

## Source evidence and licences

- Native source: `Projects/UOContent/Mobiles/Animals/Mounts/SeaHorse.cs` at `Server/dependencies.json`'s ModernUO revision. `scripts/audit-equines.py` hashes the exact constructor and checks body/item pairs.
- Installed `body.def`: `144 {200, 226} 1348`. Pinned ClassicUO `AnimationsLoader.ProcessBodyDef` selects the third group member when at least three exist; otherwise the first. This two-member group therefore selects horse body **200**, default artwork hue **1348**.
- `scripts/equine-compatibility-inputs.json` pins the client definition hashes. `scripts/audit-equine-completion.py` requires that exact resolved body/hue pair. The source definition is read locally, never copied into the repository.
- Read-only source audit: no primary-MUL body144 frames and no SeaHorse/Wisp-named members in the inspected Third Dawn archive. These bounded absences do not establish absence from every historical client or resolve every UOP/DEF precedence path. The source-table SeaHorse row remains separate evidence, not a recovered mesh.
- Local audit and three private original reference frames: `work/creatures/sea-horse/reference-audit.json`, `reference-audit.py`, `primary-reference.png`. These are ignored and not distributed.

The fallback reuses the existing **Literock Studios Warhorse Lite 1.0.0** rig, maps and four donor motions, with the project's declared action/contact adaptations. [Publisher](https://literock-studios.itch.io/warhorse-lite); exact archive/member hashes and custom licence in `scripts/horse-inputs.json`. Game use/modification is allowed; standalone asset redistribution is prohibited. Horse geometry, maps, source archives and captures remain local. This change publishes original routing/test/documentation code only; it does not put the horse asset in the public repository or change its licence.

## Runtime behaviour

`EquineRegistry` adds native body144/item0x3EB3 separately from the nine client-only compatibility bodies. Its `sea_horse` profile records fallback artwork body200 and default tint1348. The raw server body, item and hue remain intact. Zero raw hue uses the artwork default; nonzero full/partial server hues override it. No artificial horn, bags or water effect is added.

The shared horse rig supplies walk/canter/gallop, standing, reactions and project-authored categories, with existing rider saddle/stirrup/rein support. Both male and female bodies are exercised with three outfits. This is shared category animation, not original SeaHorse choreography. Native corpse graphic `0x2006` retains amount/body144, raw hue and facing; its geometry freezes the shared final Death pose and enters the existing graphic/body catalogue automatically.

## Verified focused evidence

| Check | Result |
| --- | --- |
| Native source and client fallback audits | 16 horse-rig native bodies; full catalogue 18 native + nine compatibility identities |
| Shared horse fitting regression | 4,809 checks, zero failures; 1,224 animated rider/contact poses |
| Forward+ appearance regression | 168 checks, zero failures; all 16 opaque profiles plus ethereal controls |
| Real native SeaHorse | 122 checks, zero failures; both characters and mutual observer replication |
| Review gallery | 54 actual frames / 27 identity panels; includes loose and both ridden SeaHorse views |
| Static-corpse catalogue | 174 body variants / 1,634 fresh rendered checks, zero failures |

The native test creates the actual `SeaHorse` class. Both owners use normal double-click mounting, receive the exact native layer25 item, walk/run through acknowledged server movement and dismount normally. Separate loose-animal `Move` calls replicate destination/run flags to both clients. Full/partial hues, controlled native action packets, real death, amount144 corpse packets and actual corpse presentation are checked. The guarded fixture is copied only to a unique disposable loopback2594 runtime. Production2593, accounts and saves remain untouched. Native untamable status is retained; these tests do not certify player taming, autonomous AI, water travel or final choreography.

Final focused logs: `work/creatures/sea-horse/native.log`, `equine-regression.log`, `gallery.log`, `corpses.log`. Native receipt: `outputs/ostard-riding/sea-horse-live.json`; actual gallery: `outputs/equines/index.html`, SeaHorse `04-walk.png` / `04-run-side.png`. Full root-verification outcome is recorded in the current PROGRESS checkpoint.

## Reproduction and continuation

Prepare the existing licensed horse input with `scripts/prepare-horses.ps1`. Run `python -B scripts/audit-equines.py`, `python -B scripts/audit-equine-completion.py`, `scripts/test-equines.ps1 -Gpu`, `scripts/test-horses.ps1 -Live -SkipContact -SeaHorse`, `scripts/review-equines.ps1 -Capture`, `scripts/build-corpse-catalogue.ps1 -Render` and `scripts/verify.ps1`. Native tests require the previously authorised disposable loopback access. Keep all source artwork and generated evidence local.

Continue Wisp58, AirElemental13, Ghoul, Gorilla, HeadlessOne and the configured occurrence queue. Wisp's available 2D reference is a luminous star; its named Third Dawn mesh is missing here. AirElemental's retained source is only a death-mote quad, not a full actor. Faithful authored/recovered effect actors need actual animation/hue/terrain/picking/death/corpse/native checks before routes or added coverage. Original SeaHorse geometry remains an explicit historical-source gap.
