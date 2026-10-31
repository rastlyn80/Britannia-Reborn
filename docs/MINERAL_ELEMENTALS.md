# Earth and ore elemental surfaces

Eight original source forms now have photographic mineral surfaces: earth, agapite, bronze, dull copper, copper, shadow iron, valorite and verite elementals. Original UVs, rigs and source actions are retained with the existing bounded refinement. Authored colour and reflectance distinguish ore variants. This is presentation integration, with early source anatomy still subject to art review.

The maps are pinned CC0 Poly Haven [Rock Face 03](https://polyhaven.com/a/rock_face_03) and [Rusty Metal 02](https://polyhaven.com/a/rusty_metal_02), already recorded with authors, exact download URLs, licenses and SHA256 hashes in `Viewer/Art/Surfaces/manifest.json`. `scripts/creature-minerals.py` verifies and records each input plus the authored recipe. Albedo, normal and roughness maps follow skinned UVs. Metallic response uses studio sky reflections; the normal map also supplies an actual imported tangent basis.

Reproduce from the repository root with the original local source inputs and pinned photographic maps installed:

```powershell
./scripts/test-creatures.ps1 -Families elementals -Capture
# Separately, approved disposable loopback server and two real clients:
./scripts/test-horses.ps1 -Live -SkipContact -CreatureFamily elementals
python -B scripts/build-creature-catalogue.py
python -B scripts/build-creature-actions.py
```

Verified local evidence: 4,953 finite pose checks / 1,512 skinned samples; 97 GPU checks / 48 views; 73 material response checks; 128 comparison frames; 646 disposable-server/two-client checks, all with zero failures. The normal, metal and roughness diagnostic changes affect rendered pixels; actor/camera translation produces zero changed pixels in the UV stability comparison. Acceptance rejects changed material parameters, asset/import hashes or runtime inputs after validation. Synthetic material preparation tests verify pinned hashes, license rejection and geometry preservation.

The combined accepted catalogue is 98 generic forms / 33 groups / 116 body routes. Bounded native-evidence coverage is 125/279 bodies (44.8%). Full shared regression passes 66,077 pose checks and 1,342 GPU checks. Static corpse coverage is 153 variants / 1,428 rendered checks. Original action gaps, anatomy and arbitrary terrain/effect support remain open. Air elemental is still blocked: the audited source is only a death-mote quad, not a verified full actor.

Ignored evidence is under `outputs/creatures/elementals/`; exact photographic provenance and recipes are exposed in `outputs/creatures/material-provenance.json`. The board, original comparisons, source inputs and derived creature art remain local and excluded from Git. CC0 map licensing does not grant redistribution rights to the original creature geometry.
