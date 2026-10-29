# Character and mount expansion priorities — 29 October 2026

Owner direction: gradually fill the remaining character, wearable, animation and mount gaps. Horse colours must follow the server's properties. A good-looking preview is not completion of the original client's coverage.

Implementation checkpoint: batches 1 and 2 now have functional implementations and separate appearance/transition/contact, GPU clothing and native observer tests. [HORSE_POLISH.md](HORSE_POLISH.md) records the delivered scope and remaining animation/art-quality gaps. The mount catalogue distinguishes verified routing from prototype gait/reaction art and missing animal actions; it does not inflate the human wearable count. Next expansion remains the human wardrobe worklist, alongside owner review and focused horse quality fixes.

## Appearance contract

ModernUO remains authoritative for body, mount graphic, hue, equipment, hair/beard and state. Never randomly choose a horse colour on the client. Retain raw native identifiers/hues even when the matching art is missing.

Verified in the pinned source: `Horse.cs` chooses four body/mount-graphic pairs; `BaseMount.Hue` also updates its internal mount item's hue. Our horse renderer already consumes body/hue while loose and mount-graphic/hue while ridden. The present four bodies still share one dark-bay source coat. Native hue plumbing is connected; distinct base-coat fidelity and a natural-looking tint treatment remain incomplete.

Next horse appearance work must handle both identity-based base coats and explicit server hues, including zero/default and the native partial-hue flag. Determine exact base-coat mappings from the original reference assets rather than guessing from array order. Separate coat/mane/tail/tack regions for material control while retaining the source normals/roughness/metal response; document any artistic interpretation of native tinting. Test a hue change received during riding, after dismount, on re-entry, and in an observing client. No new client-selected appearance properties should be presented as server-authoritative.

## Ordered batches

1. **Horse appearance fidelity.** Add the four ordinary base-coat variants, natural hue handling and a colour review sheet. Check identity/hue consistency between the loose animal and mounted form on both humans. This is the next recommended implementation batch.
2. **Horse and rider motion polish.** Improve stop/start/turn transitions, relaxed upper-body motion, rein and weapon-hand contact, split robe/skirt/kilt tailoring, and hoof contact on slopes. Add a full mount/dismount sequence that follows server confirmation and can be interrupted safely. Add missing animal hit/death and any other actions actually used by the server; a jump or rear preview must not invent server movement or gameplay. Source a proper fast gait where needed rather than claiming speed-scaled canter is a complete library.
3. **Human wardrobe expansion.** Resume the indexed wearable worklist, prioritising everyday civilian/vendor outfits, missing armour families and frequently equipped weapons/shields. Audit the existing 65 categories first so this fills actual gaps rather than adding aliases to an existing silhouette. Each batch must work on both bodies, on foot and riding, with native dyes, hair layering, coverage and hand contact. Keep the denominator at 1,126 unless a documented census revision justifies a change; current category mapping is 234/1,126 (20.78%).
4. **Complete human state and action behaviour.** Audit combat, ranged support hands/release/reload, casting, hit/death/resurrection, fidgets and interruption/transition cases. Include humans generated from server NPC appearances. The 35/35 connected classic categories are routing coverage, not proof that all clips, variations, layers or mounted equivalents are final. Keep unsupported seated actions explicit until authored.
5. **Remaining mount families.** Inventory actual server body/mount pairs and usage before choosing the next family. Add each with its own traceable art, size, contact profile, colours and server/observer tests; ordinary horse art must not stand in for unrelated creatures. This does not authorise a general monster-art expansion ahead of the unfinished human work.

Work can return to a later batch while an animation/source dependency is unresolved, but the gap remains open in the catalogue. Do not mark it complete with an arbitrary fallback.

## Catalogue and completion evidence

Maintain the existing human item/action catalogue and add a mount worklist with separate fields for native identity, source/licence, replacement art, supported actions, colour fidelity, runtime connection, visual quality, tests and owner review. Count category mapping, per-item design fidelity and finished motion separately.

For each batch record: before/after counts; exact implemented identities/actions; reproducible source/licence/hash data; male/female and relevant clothing samples; native dye/appearance evidence; real server movement/observer evidence when applicable; and remaining gaps. Use explicit states such as missing, prototype, connected, verified and owner-reviewed. Preserve the original body/bind/UV and converter/IR foundations, proprietary-input exclusions, remembered login and shared concurrent work.

Current baseline and finite-test limits are in [HORSE_RIDING.md](HORSE_RIDING.md), [HUMAN_COVERAGE_SESSION.md](HUMAN_COVERAGE_SESSION.md) and the latest entries in [PROGRESS.md](PROGRESS.md). Historical milestone notes may describe an older deferred state; the latest evidence takes precedence.
