# Civilian clothing and hair layering — 28 October 2026

Human players and NPCs, bodies 400/401. Four additional fitted categories:

| Native graphics | Current category | Source / treatment |
| --- | --- | --- |
| 0x1f7b, 0x1f7c | Leather doublet | CC0 RehmanPolanski Viking tunic derivative: sleeves removed, shorter hem, smoothed openings, leather material |
| 0x1515, 0x1530 | Long cloak | Authored topology using the existing eight garment controls and traced CC0 linen/fabric |
| 0x170f, 0x1710 | Low leather shoes | CC0 RehmanPolanski Viking boots derivative: shortened to ankle height, rebound, CC0 leather material |
| 0x170d, 0x170e | Ankle sandals | Elvaerwyn Caesar sandals, CC BY 4.0; fitted/rebound, calf straps shortened |

These replace the previous doublet/mail and footwear/boot substitutes, and add
the previously missing cloak category. They are category silhouettes, not exact
replicas of every original item. Shirt, doublet, cloak and footwear keep separate
native hues and partial-hue flags. Robes conceal the inner torso layers but keep
the cloak. Low footwear retains complete feet/ankles; experimental foot-cut masks
were rejected because they left gaps. The fixed body, UVs, skeleton and server
identity remain unchanged. No monster work or new action families are included.

## Long hair stays outside clothing

Long hair and ponytails have separate fitted tail meshes for clothing, headwear
and hoods, plus cloak-specific versions. Upper scalp geometry is tucked beneath headwear while the long
sections remain visible. The tails fit a fixed-body outer garment envelope and
blend toward the upper spine below the head, reducing rigid head-only movement.
When a cloak is worn, the lower sections inherit its fitted surface bindings
and clearance, so its animated back panel does not swallow the hair ends. Long
sections drape behind that panel; local card subdivisions preserve the UV/alpha
silhouette while following its curve.
The uncovered body retains the original hairstyle. Hair remains depth-tested;
it is not drawn through the face or through objects in front of the character.
Native hair IDs and hair/beard/item colours remain independent.

The current fit covers the installed clothing, cloak, hats and helmets. This is
a finite wardrobe envelope, not strand simulation or universal collision with
future armour. New garments must join the fitting/visual review before acceptance.
Short/bob/afro styles retain the existing headwear concealment rules.

## Source and licence evidence

`scripts/character-expansion-inputs.json` pins exact archives, URLs, source/member
hashes, authors and licences. The static importer accepts the selected older
signed reference-box offset format as well as the existing scale format. It
does not execute downloaded asset code. Attribution is available from the login
screen's **Character art credits** and in `THIRD_PARTY/Human-Wearables.md`.

- Official MakeHuman shoes02 CC-BY pack:
  https://static.makehumancommunity.org/assets/assetpacks/shoes02.html
  Download: https://files.makehumancommunity.org/asset_packs/shoes02/shoes02_ccby.zip
  SHA-256: `1b544d87dd8b3d3a9c8317e4f059be456491be979cbc9984fc53f403046f5061`.
- Sandals: https://www.makehumancommunity.org/node/1915 . Author Elvaerwyn,
  CC BY 4.0. The pointy flat-shoe candidate (node/1714) was rejected after
  rendered review; its hashes remain research evidence only. Accepted low shoes
  derive from CC0 Viking boots: https://www.makehumancommunity.org/node/2619 .
- Leather001: https://ambientcg.com/a/Leather001 , CC0. Download:
  https://ambientcg.com/get?file=Leather001_1K-JPG.zip . SHA-256:
  `8d3ac9280bec6a1e1e5384b93e5130414a085033290dde305bacaddd0aa6b96a`.
  Only pinned JPEG members are extracted. Colour and OpenGL normal maps are used;
  roughness is a tuned scalar, not the downloaded roughness map.
- Existing suits02, hair/body and fabric sources retain their earlier pinned
  manifests and notices. The new cloak geometry is authored in project code.

Downloaded/extracted sources stay under ignored `work/`; prepared GLBs stay in
ignored `Viewer/local-art/`. Generated provenance records recipes and final
output hashes. No artwork, game inputs, screenshots or test credentials belong
in the public source commit.

## Reproduction and checks

With the existing free body/runtime wardrobe and 45-clip motion prepared:

```powershell
./scripts/prepare-human-civilian.ps1
python -B scripts/build-human-civilian-review.py
$g=(Get-ChildItem .tools/godot/*console.exe|Select-Object -First 1).FullName
$env:APPDATA=Join-Path (Get-Location) '.godot-user'
$env:LOCALAPPDATA=$env:APPDATA
& $g --headless --path Viewer --editor --import
& $g --path Viewer --script res://Presentation/HumanWardrobeCatalogue.gd -- "--jobs=$((Get-Location).Path)/outputs/human-wardrobe-2/jobs.json"
./scripts/build-human-catalogue.ps1 -NoOpen
./scripts/verify.ps1
./scripts/test-human-batch.ps1 -Live -Visual -Cosmetics -Motion
./scripts/test-login.ps1
```

For a fresh asset bootstrap the static expansion can run before motion; it marks
pose fitting pending. Prepare motion, then rerun the expansion/civilian wrapper
before accepting the batch. `-VerifyOnly` checks the prepared civilian exports
without rebuilding. Hair fits can be rebuilt independently with Blender running
`scripts/prepare-human-hair-layers.py`.

The civilian pose fitter corrects bind-space vertices against the real skinned
body across 12 requested clips and eight phases. Cloaks use the runtime's cloth
attack and jog substitutions. The independent validator reports near contacts
and fails for deep sampled penetration or excessive floor excursion. Footwear
floor tolerance is relative to the posed bare foot because live foot-contact
correction is a separate modifier. These are vertex checks, not triangle-level
collision proof or cloth physics. Layered outfits still need rendered review.

## Acceptance evidence

- 22 pinned licensed source assets (including explicitly rejected research
  candidates), six importer tests and eight UOP parser tests pass.
- 134 exported parts/masks, normalized weights/UVs and unchanged 61-joint rest
  bindings pass, including twelve fitted hair variants per body. Each accepted
  part's final hash matches its local provenance.
- 768 civilian poses: three near-contact vertex samples, zero deep penetration
  or floor-clearance failures. The earlier 816 skirt/robe poses also pass.
  Ninety prepared clips retain body error below 0.000001 m; no clips were added.
- Shared runtime checks pass: 19 first-batch, 39 expanded appearance, 20 prior
  wardrobe/dye, 46 civilian/hair and 60 motion checks. The 37 actual Forward+
  render jobs cover both sexes, independent dyes, layering, footwear, headwear,
  walking/jogging/casting and long hair over the cloak.
- A separate GPU depth check passes 168 tail-visibility cases: two sexes,
  long/ponytail, seven clothing combinations (including cloak with hood/helmet),
  Idle/Walk/Cast at two phases. It compares coloured tail pixels with garments
  shown/hidden on the same pose, retaining the complete body's depth in both
  views and excluding the intentionally covered scalp. Every sample retains
  more than 99.5% of its reference tail pixels (98% required). This is a finite
  rear-view check, not all-view/all-action proof. Run it with
  `scripts/test-human-batch.ps1 -Visual`; it does not require a live server.
- Catalogue rebuilt: 20 equipment categories, 86/1,126 graphics category-mapped;
  23/35 classic action groups, 45 prepared clips per body remain unchanged.
  Each wearable and item/action CSV now identifies its current replacement part.
- Full `scripts/verify.ps1` passes on the current shared project, with zero
  engine/script errors. The earlier isolated committed-world-plus-character
  run also passes on baseline `4451ddb873237b78c4d5623632b9b487ac7b31a0`.
  Concurrent world edits are preserved and excluded from this character commit.
- Native login packet tests pass (8/8). Live re-entry/equipment/observer/login
  smoke was attempted but could not complete: the server listens on loopback
  2593, while new connections abort before login can be sent (Godot reports
  `Login send failed`; a delayed credential-free socket probe reports Windows
  error 10053). No account, firewall, gameplay, runtime configuration or save
  changes were made to bypass this blocker. Live acceptance remains pending.

Final local evidence: `work/human-wardrobe-2/cloak-final.log`, `hair-cloak.log`,
`repro-final.log`, `hair-layer-accepted.log`, `motion-regression.log`,
`hair-final-render.log`, `verify-isolated.log`, `verify-shared-final.log`,
`live-final.log`, `live-direct-errors.log`, `login-retry.log`, `catalogue.log`;
`outputs/human-wardrobe-2/pose-validation.json`, `hair-visibility.json`, `render-audit.json` and rendered
PNGs. The isolated snapshot records the baseline and exact overlay file list.

Remaining: owner artistic review; hair-card edges/volume, shoulder/waist
layer intersections in untested combinations, actual cloth/strand dynamics,
exact original item designs, shields/two-handed/ranged fitting and full human
action coverage. Skin remains three approximate presets. No universal layering,
all-action collision freedom, non-human port or multiplayer movement is claimed.
