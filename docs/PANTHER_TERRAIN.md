# Panther and talisman Panther on uneven ground

Both stock ModernUO identities use body 214 and hue `0x0901`. The Panther keeps its taming, feline pack instinct, ten hides and one meat. The Panther talisman creates the stock `SummonedPanther`, assigns a follower slot and starts its Follow order. Both bodies produced native static corpses in the isolated trial.

The Age of Shadows model table links body 214 directly to `Animals/felines_panther_lod2.grn`. The 132-point model has 250 triangles, 32 joints and the original `felines_panther_v03.tga` atlas. The recovered cabinet contains the original attack, fall, fidget, hit, idle, run and walk motions. The locally prepared client keeps Panther's existing Classic action routes and fitted rear swipe, alternate fall, stretch and sniff. It applies the same visual foot, tail and head support used for Cougar to the Panther's own model and clips.

The pinned Enhanced 4.0.117.33 sequences, definitions, frame manifests and loose AnimationFrame4 directory contain no direct entry or group for body 214. Both game modes retain Panther's verified Classic actions. The audit leaves unknown archive aliases open.

## Verification

- The 2,600 full-skin samples cover three planar surfaces, both sides of a 22 cm step, four facings and ten distinct movement and action clips. The original presentation penetrated by up to 339 mm in the fixture. The updated minimum gap was 2.995 mm. The maximum whole-model correction was 113.3 mm on the sampled step.
- Seventy-two transfers from moving, idle and falling poses produced 1,800 fall samples. The initial joint-position change stayed below 0.6 micrometres. The final skin settled within 0.01 mm of its 2 mm clearance target.
- Classic and Enhanced client replays passed 12 checks each. They include both Classic gestures, both fall endpoints, both packet arrival orders and a late dye on the frozen corpse.
- Two isolated ModernUO clients passed 58 checks across both player sexes. They exercised native walk, run, wrestling, hit and Animal Taming, and activated the equipped stock Panther talisman through the normal item-use packet. Both native classes produced visible frozen corpses. The fixture supplied the disposable starting conditions and requested death through the stock API.
- Six Forward+ comparison views show the original and updated renderer with the same Panther asset and hue.

Run the three `scripts/test-panther-living-*.gd` checks in a prepared viewer, or run `scripts/verify.ps1`. The public source contains the renderer selection and tests. The original cabinet members, fitted models, captures and isolated trial receipts stay in local storage.
