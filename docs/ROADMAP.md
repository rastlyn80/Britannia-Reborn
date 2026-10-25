# Roadmap

| Milestone | Status | Acceptance / remaining work |
|---|---|---|
| 0 Audit | Completed for imported code/dependency inventory | Baseline tests and architecture documented |
| 1 Authentic conversion | Implemented/tested for small Trammel base+diff crop | 15 parser checks and real viewer load pass; independent in-game comparison outstanding |
| 2 ModernUO integration | Godot and native ClassicUO entry verified locally | Compressed game login, character creation/selection and actual spawn pass; ClassicUO observer and Godot primary both entered the running server |
| 3 First playable multiplayer | Local proof of concept implemented and tested | Real character entry, ACK/wall rejection, two-client movement observation, backpack opening/contents and actual keyboard-driven scene pass |
| 4 Reconstruction | Complete crop ID catalogue implemented/tested | All 187 IDs / 2,689 records accounted for with confidence and grouped parts; solid collision and modules/procedures; exact silhouette, gables/hips and other-region coverage remain |
| 5 Gameplay presentation | Planned | Inventory/equipment, skills, combat, spells, NPCs and containers using server logic |
| 6 Full facets | Planned | Complete streamed Trammel, other facets, deterministic chunks/LOD and seam tests |
| 7 Platforms | Planned | Desktop exports, Android controls/performance, then Apple signing/testing |
| 8 Polish | Graphics/traversal pass implemented/tested | CC0 environment/furniture, camera collision, real run, local ceiling-aware jump and animation; physical replicated jump, equipment and further polish remain |
| 9 Production | Planned | Security, load tests, backup/restore, updates and operations |

Current slice complete: bounded source-backed prediction, rest-pose retargeting/continuous facing, connected roof/facade construction with corrected roof anchors, source material polish and server recovery tools. Next: strengthen latency/reconnect behavior, add foot IK and equipment presentation, then an item pickup/drop path. Numeric facet/file profiles, input bounds/provenance, independent map comparison and ClassicUO coexistence remain explicit debt. See PLAYABLE_POC.md for exact scope.

Input/login correction: mouse capture/release and focus handling tested; controller input requires opt-in; last Windows login is encrypted and prefilled. Visual material/lighting pass improves readability; faithful architectural silhouettes, roof joins, terrain materials and character art remain explicit presentation work.

Latest evidence: 117 offline checks; live six-step walk/run with exact server reconciliation and a second client observer; saved-account recovery to the Britain start; roof/wall centre and shared-edge tests. See STREET_MOVEMENT_PASS.md.

Visual quality target: polish one complete Britain building plus its street as the reference scene before extending the art treatment. Priorities are joined architectural volumes and supported props; bevels/proportions and higher-quality furniture; coherent surface scale, roughness and material variation; interior/exterior lighting and shadows; natural ground/foliage transitions; then character animation/foot contact and camera polish. The source grid is geographic input, not a requirement for visibly blocky final geometry. Current captures are reconstruction evidence, not a finished-art target.

Shared visual pass implemented: topology-based explicit/implicit corners, narrow storey seams, complete wide arches, unsupported gable suppression, bevelled timber props and bounded wind/water shaders. See VISUAL_PASS_02.md. Larger-map ID coverage and chunk-halo ownership remain unverified; art quality is still in progress.
