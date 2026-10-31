# Equine catalogue closure and llama verification

31 October 2026. The **client presentation catalogue covers all 26 indexed
terrestrial equine body IDs**: **17 native identities plus nine explicitly
labelled client-only compatibility categories**. All three native ethereal
equine item forms are routed. This is category/identity coverage, not 26 species,
26 bespoke meshes, every historical animation, or unconditional gameplay access.

The ordinary, rideable, pack and ethereal llama forms are also integrated and
verified. Original source art, licensed modern geometry, native body/item IDs,
raw hues, rider restrictions, stats and world coordinates retain their existing
ownership. Human wearables remain **732/1,126 (65.01%)**.

## Native identities

| Form | Body / mounted item |
|---|---|
| Four ordinary coats | 0xC8/0x3E9F; 0xE2/0x3EA0; 0xE4/0x3EA1; 0xCC/0x3EA2 |
| Three nightmare appearances | 0x74/0x3EA7; 0xB2/0x3EA9; 0xB3/0x3EB7 |
| Silver / holy steed | 0x75/0x3EA8 |
| Unholy steed | Shares 0x74/0x3EA7 |
| Fire steed; unicorn | 0xBE/0x3E9E; 0x7A/0x3EB4 |
| Four faction appearances | 0x76/0x3EB2; 0x77/0x3EB1; 0x78/0x3EAF; 0x79/0x3EB0 |
| Pack horse | 0x123; no mount item |
| Living ki-rin | 0x84/0x3EAD; server allows male riders only |
| SkeletalMount / HellSteed / GrizzledMare / RedDeath | Shared 0x319/0x3EBB; server hue retained |
| Ethereal horse / unicorn / ki-rin | Items 0x3EAA / 0x3E9B / 0x3E9C; no loose mobile body |
| Ordinary Llama / RidableLlama | Shared body 0xDC; only RidableLlama equips 0x3EA6 |
| PackLlama; EtherealLlama | Body 0x124, no mount; item 0x3EAB, no loose mobile |

Ethereal ki-rin reuses the accepted ki-rin rig/atlas with spectral rendering and
four-foot support. Its statuette is **0x25A0**, not a creature body. The native
EtherealKirin item allows **both sexes**; living Kirin's restriction is not
incorrectly inherited. Actual layer-25 packets still select each form.

Both the older four warhorse classes and FactionWarHorse use the existing
appearance routes. Disposable tests now cover non-member refusals and successful
rides for ranked members of all four factions. Membership/rank is test setup;
ordinary upstream double-click validation remains active. No gameplay code changed.

**Remaining server blocker:** authorised HolySteed/UnholySteed rides cannot yet
be certified with the pinned server's ethics eligibility. Their shared artwork
and neutral-rider refusals are verified; positive ethical-rider coverage remains
open. The isolated runtime reported neither ethics identity available for both
test characters. Detailed investigation stays local, separate from this client
change; no server source modification or upstream submission was made. Thus
this is not a claim of 100% end-to-end completion of every equine gameplay case.

## Historical compatibility entries

`EquineRegistry.COMPATIBILITY` keeps these separate from native server bodies:

| Body | Read-only reference evidence / presentation |
|---|---|
| 0x72 | Explicit horse fallback to 0xE4; default artwork hue 1109 |
| 0x73 | Explicit horse fallback to 0xE2; spectral artwork default 0x4001 |
| 0xB1 | Explicit horse fallback to 0xE2; default artwork hue 1109 |
| 0xBF / 0xC0 | Explicit horse fallback to 0xE4; spectral artwork default 0x4001 |
| 0x312 | Explicit fallback to horse 0xC8, hue 2101; original type row says MONSTER |
| 0x11C | Named Mondain's Steed ANIMAL row and Bodyconv target; shared steed category |
| 0x57F | Named Horse_Unicorn_RB ANIMAL row and Bodyconv target; unicorn category |
| 0x580 | Named Horse_Palomino ANIMAL row and Bodyconv target; palomino category |

No matching constant body assignment/mount constructor was found in the pinned
content source for these nine IDs. That bounded search is not a proof that no
dynamic/custom use exists. Some rows have their own source animations; a fallback
does not establish their exact species, anatomy or native action interpretation.
The named final three are modern category interpretations, not recovered 3D art.
They have **no invented mount item**. Body.def defaults affect artwork only when
the received hue is zero; the original body and raw hue stay unchanged.

`scripts/equine-compatibility-inputs.json` pins the installed Body.def, Bodyconv.def
and mobtypes.txt hashes. The read-only audit verifies the six fallback targets,
the named animal rows and the absence of constant native body assignments.
ClassicUO's ProcessBodyDef selects the third member of groups with three or more
entries; the audit follows that rule. Original game tables/art are not committed.

## Actions and clothing

All **12 named classic low-animation groups** have category replacements:
walk, run, stand, eat, three attacks, two deaths, two fidgets and lie down. Unknown
slot 4 remains unsupported. New feeding motion lowers the actual mouth on the
existing rigs. Lying reuses the source/authored collapse, holds while stationary
without marking the creature dead, and resumes gait/contact on movement. Attacks,
fidgets and deaths still share category art; exact native choreography remains
separate. The MONSTER-tagged historical fallback is not certified for a distinct
original high-group action library.

The female ethereal ki-rin's bent-arm views initially exposed forearm skin at
the manufactured sleeve openings. New authored, closed, overlapping textile
sleeves follow the actual lower-arm/hand bones and use the existing traced
lining material. Body geometry/masks and acceptance thresholds are unchanged.
Rejected chest/gusset trials are unused local drafts. Final rendered coverage
passes for plate, robe, skirt and kilt, including ranged and transition poses.

## Evidence and reproduction

ModernUO revision: `ab59efea86fd9e399d261bed9d188ab4d95ad4c2`.
Exact source/reference hashes and all detailed reports remain in ignored outputs.

| Accepted check | Result |
|---|---|
| Equine completion live / two clients | **964 checks, 30 class/gender/setup cases**, zero failures |
| Llama completion live / two clients | **232 checks, eight class/gender cases**, zero failures |
| Nine compatibility bodies / actual avatars, hues, skin, corpses | **1,869 checks / 864 sampled skin poses** |
| Known animal action categories / 31 body presentations | **2,883 checks / 1,116 poses** |
| Distinct mounted rider fitting | **3,252 checks / 1,440 poses**, plus turned-facing checks |
| Source/skeletal skin actions | **1,323 checks / 621 poses** |
| Flat and two slope samples | **63 checks / 21 samples** |
| Actual GPU clothing regression | **2,176 views**, zero failures |
| Expanded ethereal ki-rin clothing | **512 views**, zero failures |
| Compatibility dyes / ki-rin transparency versus opacity | **40 GPU checks**, zero failures |
| Retained horse regressions | **2,468 checks / 768 contact poses**, plus 267 polish checks |
| Full scripts/verify.ps1 | Exit 0; existing unrelated bridge missing-id, Unicode, nullable and teardown diagnostics remain |

Live tests create disposable accounts/characters and exercise real world entry,
native mounting/casting, dyes, walk/run and return, observer replication,
restrictions, dismount, four native action packet categories, real death and
matching corpse presentation. They never attach to the production world or saves.
Offline skin samples and local review captures are not multiplayer claims.

```powershell
python -B scripts/audit-equines.py
python -B scripts/audit-distinct-mounts.py
python -B scripts/audit-equine-completion.py
./scripts/review-mounts.ps1 -Validate
./scripts/test-horses.ps1 -Live -SkipContact -EquineCompletion
./scripts/test-horses.ps1 -Live -SkipContact -LlamaCompletion
# Also run AnimalActionTests.gd / EquineCompletionTests.gd headlessly;
# EquineCompletionAppearanceTests.gd and DistinctMountClothingTests.gd use GPU.
./scripts/verify.ps1
```

Reviews remain under **Reviews/**. The local equine gallery has 52 real frames;
the integrated mount gallery has 109, including ethereal ki-rin and pack llama.
`CharacterCoverage.gd` now reports installed availability and native/compatibility
identities separately. The wider creature queue remains ongoing. The aquatic
SeaHorse (0x90/0x3EB3) belongs to that separate family, not this terrestrial index.
Exact anatomy/material/choreography polish, arbitrary outfit/terrain combinations
and distributable clean-install asset packaging remain explicit work.
