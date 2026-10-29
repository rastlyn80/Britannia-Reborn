# Live collaborative developer editing — 28 October 2026

Authorized developers can edit statics and terrain from inside the running Godot client, see each other's previews and accepted edits without restarting the server or rebaking the world, and keep the result as a reviewable edit set. This is a working vertical slice inside live streamed Britain (Trammel X 1088–1791, Y 1408–1919), not a world editor for every facet.

Owner direction (28 October): this is the foundation for talking to the world. A developer or game master states a change, and the change happens through the same command model. That covers the in-game panel, scripts and Claude Code now, and voice later. Voice/AI integration is follow-up work; nothing here depends on an external AI service.

## What exists and how it fits

Nothing replaces the converter → IR → prepared-district pipeline. Additions:

| Layer | Files | Role |
|---|---|---|
| Bake source map | `Presentation/DistrictBatch.gd`, `CompactDistrict.gd`, `PreparedDistrict.gd`, `BakeStreaming.gd`, one tag in `Reconstruction.gd` | Each prepared district records which merged vertex range, multimesh instance or node belongs to each static (`x:y:z:id:k`). It also stores the kind/state, and the original positions of live-editable batched statics. Geometry is unchanged; caches baked before this have no map and refuse static edits with a clear reason. |
| Server authority | `Server/PreviewTools/DevEditSession.cs` (pure logic), `DevEditCommands.cs` (ModernUO adapter) | Validated, totally ordered operations with per-target revisions, attribution, reservations, shared previews, undo/redo rules, an append-only journal and deterministic edit sets. Isolated extension assembly; no core or gameplay edits. |
| Transport | `Network/GameSession.gd` (`send_dev_edit`, `dev_edit_received`) | Reuses the native connection: `[DevEdit …` speech commands (≤128 chars, paced ≥60 ms for the speech throttle). Replies are `UCEDIT1|…` system messages, the pattern already used by `UCENV1`. No extra service. |
| Client model | `DevEdit/DevEditState.gd` | Mirror of accepted server state, history-derived undo/redo stacks, request lifecycle (pending/applied/failed) and the textual command builders. |
| Overlay | `DevEdit/DevEditOverlay.gd`, `DevEditTerrain.gd`, `Presentation/LiveDistricts.gd` signals | Applies the overlay to installed districts and re-applies it on every install, covering unload/reload. Handles selection by ray against source records, previews and terrain jobs. |
| Panel | `DevEdit/DevEditMode.gd`, `World.gd` (F9) | Developer panel; click routing while active. |
| Assistant bridge | `DevEdit/DevEditCli.gd`, `scripts/dev-edit.ps1` | Same commands from a terminal, with JSON results, so Claude Code can act in a live session. |

### Edit model

The converted world stays an immutable baseline. The overlay maps stable targets to canonical states. `""` means baseline.

- `s:X:Y:Z:ID:K` — an existing static. K ranks identical source records in source order. States: `hide`, or `m:X:Y:Z:YAW:ID`, an absolute placement that may move it (fractional tiles, ≤8 tiles / 40 Z from the original), rotate it, or replace it with an approved graphic.
- `p:N` — a placed decorative object, numbered by the server: `a:ID:X:Y:Z:YAW`. Only graphics in `DevEdit/approved-assets.json` (non-blocking decorations) are accepted.
- `t:X:Y` — a terrain height sample: `h:DZ:SURFACE` (±40 UO Z; surfaces grass, forest, dirt, cobblestones, sand, brick, or `-` to keep).

Each change records its revision and author. An edit must name the revision it was made from; otherwise it is refused as a conflict that names the newer editor. Undo/redo apply only to the requester's own operations, and only while every touched target still holds the revision that operation produced. An undo that would overwrite someone else's newer change is refused, never merged silently. Reservations (`lock`, 120 s, refreshed by edits, released on leave/disconnect) cover single targets and terrain discs (`r:X:Y:R`). Terrain brushes are discs of radius ≤6 with a deterministic integer falloff shared by server and client. Concurrent brushes compose in server order.

### Rendering, without a second converter

- **Hide / move / replace an existing static.** Its own baked geometry is collapsed in place: the static's contiguous vertex range in the merged batch (one position-stream upload of the stored original positions; no GPU readback), its multimesh instance (zero-scaled), or its node (hidden). Moved or replaced statics get a live visual built by the shared `Reconstruction.build`. Restore writes the stored originals back exactly.
- **Joined architecture** (walls, roofs, floors, stairs, doors, fences, trims, signs, water and other joined/special surfaces) and multi-tile assemblies can be selected and inspected, but are not live-editable. Collapsing one would break joined wall/roof topology; this needs a district rebake. The panel shows the reason.
- **Terrain.** Each affected district's baked terrain mesh is deformed from its immutable base by the bilinear interpolation of per-sample deltas, and surface paint blends the existing vertex colour/mask channels used by `Ground.gdshader`. Shared border vertices sit at identical source positions and receive identical displacement, so neighbours meet without cracks. Only cells that changed are recomputed, on a worker thread (at most two jobs). The new mesh is swapped in on the main thread, and the previous mesh stays visible until then. A generation counter, bumped when an edit is *scheduled*, discards stale results.
- **States.** Local drafts (yellow, "DRAFT"), shared previews (per-author colour, "PREVIEW · name", translucent, never persisted) and accepted edits (normal rendering plus a green "author · rN" tag while the panel is open) are visually distinct. The activity list shows pending/applied/failed requests and remote operations.

### ModernUO authority and collision

Everything in this slice is a **visual overlay**. ModernUO's map, statics, items, movement, line of sight and saves are not changed. Client collision and native movement prediction keep the baked baseline, so they agree with the server:

- Hiding or moving a blocking static leaves its tile blocked; the panel says so ("VISUAL PREVIEW ONLY …").
- Terrain height edits do not change walkable elevation; the avatar keeps following server Z, so a raised patch can visibly bury its feet. This is flagged, not hidden.
- Placed objects are non-blocking decorations with no collision on either side.
- The far/middle-distance LOD and the radar keep the baseline until a rebake.

Making any of these authoritative needs a ModernUO-side map/statics change: either map/statics file regeneration plus a server restart, or a server-side runtime map overlay. The pinned server does not support either without core edits. That is the precise remaining blocker, and it was not bypassed.

### Persistence and review

- `Server/runtime/DevEdit/session-<name>.json` — the session journal: every accepted operation in order, with before/after states. It is written atomically before an operation is announced, and replayed and fully re-validated at startup; a journal that does not replay is refused rather than partially loaded. It is ignored (under `Server/runtime/`), separate from ModernUO saves, and never touches the gameplay world.
- `save NAME` writes `Server/runtime/DevEdit/sets/NAME.edits.json`, a deterministic, sorted, schema-1 edit set of final states with attribution. `load NAME` imports one as a single undoable operation after validating format, baseline and every entry.
- Edit sets contain exact source coordinates and graphic ids and are marked `"privacy": "local …"`; they stay local. Only the explicit Commit publishes edits to Git (see Commit below).

## Talking to the world and group edits — 29 October 2026

- **Ask box (panel).** Type a request, or speak it with Windows voice typing (Win+H in the box). An offline, deterministic interpreter (`DevEditIntent.gd`) maps common requests to commands: "hide the flowers near me", "put two baskets in front of me", "raise the ground here by 6 radius 3", "paint the ground here with dirt", "replace the mushrooms within 5 tiles with foxglove", "move them 2 tiles north", "rotate it 90 degrees left", "remove everything I placed", "undo", "save this as market-day". It never guesses: an unknown request or an unapproved asset is reported, and **Ask Claude** forwards the sentence instead. "Speak replies" reads answers aloud with the system voice.
- **Scope before applying.** Every request, proposal and group action is dry-run first (`DevEditCommands.plan`). The panel lists exactly what will change, highlights every target, states what was skipped and why (for example joined architecture), and flags visual-only effects. Nothing changes until **Accept**; **Cancel** declines.
- **Rule scopes and multi-select.** Rules such as `name~barrel;near=1602,1591,12`, `kind=flower;rect=…`, `placed;by=Name` or `…;edited` (`DevEditQuery.gd`) must be bounded (radius ≤32, rectangle ≤96×96, or your own placed/edited targets). Shift+click builds a selection; the panel buttons then act on all of it. A group is sent as one atomic, attributed batch (`batch begin/add/commit`, ≤256 targets): one revision, one undo, refused entirely if any target is invalid, stale or reserved. Shared group previews carry the rule, and each client evaluates it on its own loaded records.
- **Claude Code link.** `scripts/dev-edit-bridge.ps1` keeps a headless editor connected as "Claude". Each request, answer, proposal and edit is appended to `work/dev-edit-bridge/outbox.jsonl`; lines appended to `inbox.txt` are executed (`inspect`, `answer ID TEXT`, `propose ID CMD && CMD`, `preview`). In a Claude Code session, ask Claude to watch the bridge. The server keeps open requests, answers and proposals for late joiners, and writes an audit trail to `Server/runtime/DevEdit/conversation.log`. Proposals are only text: the asker's own client applies them, attributed to the asker, after Accept.
- **AI edits follow exactly the manual flow.** The server refuses every world-changing command from the assistant role (set, place, brush, batch, undo/redo, locks, edit-set load/save; `DevEditSession.AssistantMay`); it may only ask, answer, propose, resolve, preview and read status. Typed or spoken requests and Claude's proposals open the same review: affected objects highlighted, and the result drawn as a draft in the world (placements and replacements as ghosts, hides in red, restores in green, terrain discs) before Accept. Accepted, they are ordinary live session edits, which become permanent only through Commit. Live evidence: 41/41, including the assistant's direct placement being refused with the revision unchanged. Behaviour rules that need code (roofs attached to walls) are code changes, reviewed as Git commits, not world edits.

Evidence: server 64/64 (batches atomic/stale/duplicate/one-undo; conversation parts, answers, proposals, asker-only resolution); client 67/67 (24 new: interpreter phrasings and refusals, bounded/malformed rules, skip reporting, batch encoding within the speech limit, selection shift/rotate, multi-part asks, proposal assembly); live two-client 40/40 (a three-object group moved in one revision and undone in one step for both clients; the assistant role received a request, answered, proposed two commands; the asker dry-ran and applied them as its own edits and closed the request). Real bridge run: a developer client asked "make the corner by the inn at 1606 1588 look festive with flowers"; the offline interpreter declined it; Claude, watching the bridge in this session, inspected the spot, answered and proposed four placements with scope; the asker received the proposal after reconnecting and declined the demo.

## Commit, persistent rules and live reload — 29 October 2026

Owner request: preview statics before placing them, commit static and terrain work whenever needed, and state *future* rules by voice ("make sure all roofs are always attached to the walls") so they take effect in the world.

- **Previews.** In the Place tool the chosen asset follows the cursor as a translucent preview until a click fixes it; choosing a different asset while a static is selected previews it as the replacement in place. Shared previews (Preview button) remain separate from accepted edits.
- **Commit** (panel button, or saying "commit", "make this permanent", "bake it into the world"). The plan shows how many statics, placed objects and terrain samples will be committed, by whom, and which districts rebake. Accept does three things:
  1. It folds the session into `outputs/<region>/overrides/committed.overrides.json` (`Presentation/ManualOverrides.gd`): absolute states for statics/placed objects, while terrain deltas add to previously committed heights. A timestamped copy goes to `history/`.
  2. It starts `BakeStreaming.gd` in a background process. Each district's stamp now includes a digest of the overrides that touch it, so only those districts rebake.
  3. When the new index is published, every running client on that machine reloads the changed districts in place (`LiveDistricts.check_index`). The old district stays visible, with its collision, until the replacement is fully installed. The committing client then clears exactly the committed targets from the live session in a `commit` batch; targets someone changed during the bake stay in the session.
- **What the converter does with committed edits** (`RegionalContext.apply_overrides`/`build_chunk`, `TerrainSurface`):
  - Hidden and moved statics still contribute their original collision but are not rendered (moved ones render at the new place, keeping their identity so they remain live-editable).
  - Placed objects render without collision.
  - Terrain renders committed heights and paint, while its collision is built from source heights.
  - Collision is therefore identical to the uncommitted bake, consistent with ModernUO.
- **Persistent rules.** "Never show weeds", "always hide the mushrooms around here", "from now on replace weeds with grasses" become bake rules (`rules` in the committed file). They apply to every matching non-architectural static in the dataset on every bake, including districts rebaked later. They are shown with their current nearby matches before Accept.
- **Behaviour rules.** "Make sure all the roofs are always attached to the walls" is not data: it is how reconstruction builds roofs. The interpreter says so and offers **Ask Claude**. Through the bridge, Claude Code receives the sentence, changes and tests the reconstruction code, and rebakes; the clients reload the result. Expect minutes, not seconds, and review the code change before it is pushed.
- **Revert.** `scripts/revert-commits.ps1` removes the committed overrides (kept in history), or `-To <history file>` restores an earlier commit, then rebakes the affected districts. `-List` shows the history.
- **Files held by running clients.** If Windows refuses to replace a district file because a client has it open, the bake installs it under a versioned name recorded in the index (`files`), and clients follow the index.
- **Sharing through Git (owner decision, 29 October 2026).** Client-side edits (statics, placed objects, terrain, data rules) go to Git; server-only state (the ModernUO session journal `DevEdit/session-*.json` and `conversation.log`) stays with the server wherever it runs. Each Commit writes one change file holding only that commit's edits (`outputs/<region>/overrides/outgoing/<id>.overrides.json`, id = UTC time + author). Once the bake succeeds, `scripts/publish-world-edit.ps1` builds a commit adding `Viewer/DevEdit/overrides/<id>.overrides.json` on top of `origin/main`, pushes it as branch `world-edits/<id>` and opens a pull request with the GitHub credential git already uses. The working tree, index and current branch are never touched. The panel shows the pull request link; on failure the edit stays committed locally and the panel prints the retry command. `UC_DEV_EDIT_PUBLISH=0` turns publishing off (the test scripts set it).
- **Merging.** The bake merges published change files in time order, then the local cumulative copy. The local copy is skipped once every commit it lists is published, so after a pull nothing is applied twice. A `""` state or a `[0,"-"]` terrain entry in a later file restores the baseline over an earlier one. Terrain deltas build on what the world shows (published plus local), so edits made on top of a collaborator's merged terrain add up correctly. Collaborators get merged edits on their next launch, and `Launch.cmd` rebakes only the districts those edits touch. Change files contain map coordinates and graphic ids only, never game art or map data.
- **Reverting a published edit.** Revert its pull request, or delete its file in a new commit. `revert-commits.ps1` only rolls back the local copy.

### Commit evidence (29 October 2026, same machine)

- Converter tests on real Britain data (`DevEditCommitTests.gd`, 15/15). Building one district with and without overrides gives identical collision (594,309 triangles). Hidden statics and a hidden tree are not rendered, and the tree keeps its trunk collision. The moved static keeps its identity, the placed object renders without collision, and rendered terrain rises by the committed 10 Z. Terrain deltas accumulate across commits; rules match by name and rectangle.
- End to end with two graphical clients (`DevEditCommitVisual.gd`). A placed a basket, hid a baked plant and brushed 29 terrain samples, then committed. The scope showed 1 static, 1 placed object, 29 samples and 2 districts.

  | | |
  |---|---:|
  | Background bake (planning ~45 s + 2 districts) | 75 s |
  | Commit to both clients reloaded | 85 s |
  | Districts reloaded per client | 2 of 9 |
  | Worst frame during the bake / during the reload (A) | 146 / 144 ms |
  | Worst frame during the reload (B) | 123 ms |
  | Session edits after the commit | 0 of 31 (all committed) |

  The baked world looked identical to the edited one before the commit: no flicker, no double application. The commit could not be undone from the session; the server and client both refuse it, because an undo would re-apply the edits on top of the baked result.
- An earlier run reloaded with `CACHE_MODE_REPLACE` and stalled 2–3 s: Godot rewrote the meshes the old district was still showing. Loading fresh copies (`CACHE_MODE_IGNORE`) fixed it.
- Revert: commit → 1 district rebuilt; `revert-commits.ps1 -Classic` → the same district rebuilt; the next bake reported `current`. The versioned-file fallback was not triggered on this machine (Godot did not hold district files open), so it is implemented but not yet exercised.
- A one-time full rebake (88 districts, about 7 minutes) follows these code changes in each graphics mode. Later commits rebuild only the touched districts.

## Launch: shared session with two clients

1. Once: `./scripts/build-preview-tools.ps1` (installs the extension and approved-asset list), then `./scripts/configure-dev-edit.ps1`. This authorizes exactly the two local development accounts; pass `-Accounts a,b` to choose others; `-Disable` turns the session off. Restart the server gracefully (save, shutdown, `Start-Server.cmd`).
2. `Launch.cmd` (first client) and `Launch-Second-Client.cmd` (second development account). The first launch after this change rebakes the prepared city once, since the bake now records source maps. That takes several minutes per graphics mode.
3. In the world, press **F9** to open the panel and join. Tools: **Select** (click a static or placed object to inspect and reserve it, then X/Y/Z/rotate/Hide/Replace/Baseline), **Place** (choose an approved asset, click the ground), **Terrain** (radius, height, surface, click the ground). The scope line shows exactly what an operation will affect before you press **Preview** (share), **Accept** or **Cancel**. **Undo/Redo** show the revision they target. **Save set / Load** manage edit sets.
4. From a terminal (or Claude Code), while the clients are connected: `./scripts/dev-edit.ps1 -Commands 'inspect 1602 1591 2; place 4153 1604 1588 20 30; list'`. This uses the second development account by default, so log that client out first or pass `-Account 1`.

## Evidence (this machine: Windows, RTX 2070 SUPER, Godot 4.7.2, local ModernUO)

Automated, offline — `scripts/test-dev-edit.ps1`:

- Server session logic: **49/49** (validation, ordering, stale-revision conflicts, reservations incl. region overlap, undo/redo ownership and conflict refusal, clamping, previews never persisted, byte-identical journal round trip, tampered/other-session journal refused, deterministic edit-set export/import/undo).
- Client, headless: **42/42** (protocol parsing and malformed/incomplete records refused, request lifecycle, undo/redo derivation, canonical numbers and brush parity with the server, synthetic border continuity, exact baseline restore; on real prepared districts: architecture identified as non-editable, hide/move persistence across unload and reload from disk, cross-border terrain rebuilding only the two touched districts with zero cracks, terrain re-applied after reload, stale terrain result discarded).
- Client with a renderer (`-Gpu`): the same 42 checks, plus byte-level verification that a hidden static's batched vertices collapse, that neighbouring vertices are untouched, and that undo restores the exact baked bytes, including after reload from disk.

Automated, live (`-Live`, two independent headless clients, two accounts, real local ModernUO): **31/31**. Placement replicated with attribution and revision; shared preview shown and cleared without touching accepted state; reservation refused the other editor; stale-revision edit rejected as a conflict; undo refused because the other editor had changed the object since (B's change left intact); own undo/redo replicated; five invalid commands rejected with the revision unchanged; a real baked static hidden for both; reconnect/late join received the newer edit, revision and undo history; cross-district brush replicated with the deterministic falloff; edit set saved with digest; every test edit returned to baseline.

Session restart: an edit placed by `-Live -Mark` was present with the same revision and author after a server restart (`-VerifyMarker`, 4/4), then removed.

Graphical (scripted, not hand-driven): `DevEditVisual.gd --role=a` and `--role=b` run as two real windowed clients with the two development accounts. They return to the Britain start point, open F9 and join one session. A places, hides and brushes; B sees each change without any restart, and A sees B's shared preview. Both panels list the same editors, revisions and attributed activity. A manual, hand-driven session with a human at each client has not been recorded yet.

## Measurements

Windows 11, RTX 2070 SUPER, Godot 4.7.2 Forward+, local ModernUO on loopback. Timings are wall clock. Edit-to-visible ends at the first frame drawn after the overlay applied the change (for terrain, after the rebuilt mesh was swapped in).

| | Editor A (sender) | Client B (receiver) |
|---|---:|---:|
| Place approved asset | 118 ms | 134 ms |
| Hide a baked static | 86 ms | 136 ms |
| Terrain brush r4 +14 Z crossing the X=1600 district border | 290 ms | 256 ms |
| Districts rebuilt by that brush (of 9 resident) | 2 | 2 |
| Worst frame from command to visible | 50 / 72 / 50 ms (place / hide / brush) | 44 / 58 / 46 ms |
| Frame p50, same session at rest | 19 ms | 45 ms |

Both graphical clients ran on one GPU at the same time, so B (the background window) had a slower baseline. The worst edit frames sit close to each client's normal frame time.

- Command round trip on loopback, headless clients: 31–47 ms (placement and brush).
- Static hide/restore/move apply: under 0.1 ms per batched static, from the stored baked positions as one contiguous upload with no GPU readback. Building a live visual for a moved/placed object: 0.5–33 ms after warm-up.
- Terrain: the worker job takes 31–39 ms for a district's dirty cells (main thread unaffected), and the main-thread mesh swap 2.3–3.9 ms per district. Only districts whose rendered terrain changes are rebuilt. In the headless and GPU suites, a stale result was discarded when a newer edit arrived first.
- One-time join cost (F9): approved assets are loaded and resident districts' terrain bases are read back, one item per frame. That is 7–51 ms per district readback on this machine (a GPU synchronization), which would otherwise land on the first terrain edit there. Districts streamed in later pay it on their first terrain edit.
- Earlier runs before these mitigations measured a 558 ms first placement (cold asset load) and a 113 ms first hide (vertex readback). Those are the reasons for the warm-up and the baked positions.

Captures: `outputs/validation/dev-edit-a-*.png` / `dev-edit-b-*.png` (joined, placed, inspector before/after hide, terrain, shared preview), with per-client JSON alongside. They are local and ignored, because they show converted owned map data.

## Remaining gaps

- Authoritative gameplay edits (walkable terrain, blocking statics, doors, line of sight) need ModernUO-side map/statics support. They stay visual previews and are labelled as such.
- Joined architecture and multi-tile assemblies are inspect-only; editing them needs a partial district rebake path that keeps joined topology.
- The far/middle-distance LOD, radar and the macro horizon show the baseline until the next bake.
- Moved/replaced statics are rebuilt by the shared rules without the bake's contact settling, so a few props can sit slightly differently from their baked look.
- Sessions cover the converted Britain bounds only; other regions need prepared districts first.
- The modern-Britain cache must be rebaked (the next `Launch.cmd` in modern mode does it) before static edits work in that mode; terrain/placements work regardless.
- Transform controls are buttons (¼/1 tile, 1 Z, 15°), not drag gizmos; there is no multi-select or rule-based ("every barrel on this street") scope yet. The command model is ready for an assistant to add them.

## Talk: local, multilingual speech (29 October 2026)

**Talk** in the F9 panel records one request from the microphone inside the game (Godot `AudioStreamMicrophone` and `AudioEffectCapture`, on a silent bus). Recording stops on the second press, after 1.3 s of silence following speech, or after 20 s. The clip is resampled to 16 kHz mono and recognized by local Whisper (whisper.cpp). It is free and offline, covers 99 languages, and no audio leaves the computer. The text fills the Ask box and opens the usual review: requests the built-in interpreter knows show their plan, and anything else goes to Claude. Nothing changes until Accept.

- **Install once:** `./scripts/setup-speech.ps1` (whisper.cpp CPU/BLAS build plus `small-q8_0`, about 270 MB in total). `-Model large-v3-turbo-q5_0 -Gpu` installs the best multilingual model with the CUDA build. Without Whisper, Talk falls back to Windows speech recognition (`scripts/listen.ps1`).
- **Panel controls:** spoken language (Auto or one of 17 listed; any Whisper code works in the settings file), **English commands** (translate speech into English so the built-in commands work in every language; turn it off to send Claude your own words), and the microphone. Settings persist in `user://dev-edit-voice.cfg`.
- **Speed:** the encoder window is sized to the clip (50 frames per second) instead of a fixed 30 s, which makes short commands about twice as fast.

Evidence on a Ryzen 9 9900X (CPU only, small-q8_0, 12 threads):

| Clip | Time | Result |
|---|---:|---|
| 8 s English command (Windows voice), through the game's own encoder | 1.55–1.65 s | Word-perfect |
| German, CC BY-SA spoken Wikipedia | about 3 s | Word-perfect; English translation good |
| Italian, CC0 sample, language set to Italian | about 2.4 s | Word-perfect; English translation good |

With Auto, the small model misidentified the Italian sample as Latin; choosing the language avoids that, as does the larger model. The real microphone delivered 72,704 samples in 1.5 s at 48 kHz. Voice tests: 7/7 headless, plus the microphone check with `-Gpu`. Not yet exercised: a real person speaking into Talk in the running game.

## Code fix previews (29 October 2026)

Some requests need a converter code change, not a world edit, for example "the wall is peeking through the roof; fix all similar cases". The owner judges such fixes in the world before they become permanent code. `scripts/code-preview.ps1` runs the whole cycle:

1. **`-New -Id <id>`** copies `Viewer` to `work/code-previews/<id>/Viewer`. The 6,789 code and text files are copied; the 9 GB of art is hard-linked, which takes about 30 s and no extra disk space. Claude edits only the copy; the main project and `main` stay untouched.
2. **`-Bake -Districts "x,y;..."`** bakes those districts with the copy's code into `outputs/<region>/previews/<id>/<classic|modern>/` (`BakeStreaming.gd --preview-output --districts`). The published cache and its index are not touched, and batches add up, so the districts near the player can come first.
3. **`-Publish -Title -Description -Examples "x,y,z,label;..."`** writes `preview.json`. Claude then proposes `codepreview <id>` in the conversation.
4. **In game:** the proposal opens a review card. The changed districts swap to the preview bake in place (`LiveDistricts.set_preview`, the same no-restart path as Commit reloads), and beacons mark example buildings. **Before/After** flips between the published world and the fix; **Next example** says where each beacon is.
   - **Accept** marks the request applied, and Claude runs `-Accept`: the changed files are copied into the main project, refused if any of them changed there meanwhile. Claude then runs the tests, commits and rebakes.
   - **Cancel** declines; `-Discard` removes the copy and the preview bake.
5. **`-Status`** lists the files a preview changes.

Code fixes are client presentation only; collision and gameplay stay as ModernUO has them. Preview bakes are local to the machine that holds the dataset.

`DevEdit/CodePreviewShots.gd` renders the same district from the cache and from a preview with one camera, to produce before/after pictures for diagnosis.


## Tame creatures: `pet <kind>` (29 October 2026)

`pet horse` (also packhorse, llama, packllama, desertostard, forestostard, dog, cat) asks the server for a creature tamed to the developer, at their feet and coming to them. Claude proposes it on a card and the developer accepts it, like every other edit; the assistant account itself is refused. It is server-only: an ordinary ModernUO creature in the world save, nothing written to Git. Kinds are an allowlist shared by `DevEditSession.PetKinds` and `DevEditCommands.PETS`; the follower limit still applies. Evidence: server tests 67/67, client tests 77/77.

## Responsive assistant (29 October 2026)

The bridge answers every new ask at once ("Got it, I'm on it…") before Claude's real reply, and the panel's conversation list ends with "Claude is online" or "Claude is offline: asks are saved and answered when it reconnects"; asking while it is offline says so in Activity. `scripts/dev-edit-bridge.ps1` now reconnects by itself after a server restart (retry every 10 s until "quit" is written to the inbox after launch), and `-Detached` runs it in its own hidden process so it outlives the shell that started it. Client tests 77/77.
