# Gazer hover and harpy surfaces

The original Third Dawn gazer, elder-gazer, harpy and stone-harpy source forms now have upgraded local atlas trials, bounded refined geometry, source/category action routes, exact raw hues and matching static cadavers. Their rigs and UVs are retained. Original inputs, generated images, exact prompts, IR and captures stay ignored under the existing provenance and distribution rules.

## What changed

Gazers have no compatible stance feet. Their source mesh already has positive authoring-space Z clearance. The previous blanket floor correction pinned the lowest tentacle to the floor and removed that motion. The explicit `preserve_hover_clips` exporter option retains positive source height and only lifts geometry that would penetrate the ground. The original death ends below the reference plane and therefore settles onto it before the static corpse handoff. This is a declared presentation policy using the source coordinates, not proof of the final released client's ground convention. Other creatures retain the existing default grounding policy.

Runtime Eat and LieDown fallbacks inherit the support policy of the Idle/Death clip they copy. Pose checks therefore distinguish source hover, source takeoff/landing and grounded animation. Harpies use refreshed 120 Hz floor sampling and the existing source-vertical flight policy; their source opacity masks now remain authoritative on modern surfaces, preserving feather gaps.

The living harpy's selected surface is an **authored, fully feather-covered variant**. The stone-harpy reference passes exact point/normal/topology/UV/weight/rig equality with the living harpy. Its UV-compatible atlas is used as the modern donor while the living harpy's own recovered atlas remains the original comparison baseline. The donor is explicit in the source reuse recipe and ignored preparation receipt; this is not described as a recovered original material.

The source gazer design remains unusual: each original mesh contains four separate ten-point eye components weighted to named eye bones. Local topology evidence is in `work/gazer-source-anatomy.json`; the separation predates refinement. Their exact visual intent and final released-client fidelity remain art-review gaps. Do not silently join or remove the original eye components to make a more conventional beholder.

## Evidence and limits

- New pose checks: **3,058**, **882** skinned samples, zero failures. New actual Forward+ checks: **64**, **24** views, zero failures. New comparisons: **64** core frames.
- Floating-avatar support: **96 checks / 18 cases**, using all three source body routes on raised/lowered flat and sloped collision planes. Measured visual height follows the surface within 15 mm; the conservative skin box clears it by at least 120 mm. Native entity transforms, raw hue and proportions remain unchanged. This is offline finite-plane presentation evidence, not arbitrary obstacle/volume clearance or native AI certification.
- Native disposable-server/two-client checks: **94 gazer / 202 harpy**, zero failures. Only body **22** currently has gazer constructor evidence in the bounded audit; both Gazer and ElderGazer use that body. Historical archive elder-gazer IDs **68/69** have presentation routes and offline evidence, not native constructor evidence. Native GazerLarva **778** remains unrouted and needs a distinct or explicit, validated reuse solution.
- Pre-acceptance frozen-cadaver checks: **24 gazer / 17 harpy**. The complete local corpse catalogue now has **145** body variants and **1,356 rendered checks**, zero failures.
- Current common creature regression: **61,124 pose checks / 18,585 samples**, **1,245 GPU checks / 540 views**, zero failures. Long-toe dragon contact and recovered spirit-effect evidence remain separate.
- Native-evidence coverage is **117/279 (41.9%)** of the bounded source audit; accepted generic presentation is **90 forms / 32 groups / 108 routes**. This is not an exhaustive modern-body denominator, original-action or final-art percentage.

The fresh combined-workspace `scripts/verify.ps1` **exits 0**, including 23 creature-pipeline and 11 Third Dawn synthetic tests, 78 developer-edit checks and the final world smoke. Separate developer-edit runs also pass all 78 checks in headless and real Forward+ rendering modes. Logs: `work/combined-creatures-full-verify.log`, `work/combined-devedit-headless.log`, `work/combined-devedit-gpu.log`. Existing unrelated diagnostics remain. Earlier runs failed while the compact-streaming fixtures/data were changing; that temporary failure is closed by the new runs. No developer-edit/streaming files were changed for this creature work.

## Reproduce

Run `scripts/test-creatures.ps1 -Families gazers,harpies -Capture` in PowerShell (or pass a proper two-element array). It runs source pose checks, the gazer avatar/support test, actual GPU checks, hash-gated acceptance, frozen-cadaver preflight and the complete corpse catalogue. Native checks use the previously approved isolated harness: `scripts/test-horses.ps1 -Live -SkipContact -CreatureFamily gazers`, then `harpies`, on port 2594. Never run these native sessions concurrently or attach them to production.

The local creature/action work board and corpse graphics catalogue remain under `outputs/creatures/` and `outputs/corpses/`. Continue native identity gaps including larva 778, remaining source monster/elemental/sea groups, full action gaps and precise anatomy/material/terrain polish. Large/floating mobile selection and label bounds also need a systematic per-body audit; the existing general avatar picking box is still coarse.
