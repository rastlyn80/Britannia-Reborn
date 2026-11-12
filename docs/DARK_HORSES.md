# Nightmare, Fire Steed and Unholy Steed

The optional Enhanced presentation uses the original later Third Dawn Nightmare and Fire Steed meshes and their separate 128×128 colour atlases. The model table links both to the body-200 dappled-brown horse's motions. The local bake rounds 442 triangles to 7,072, retaining the 37-joint rig and all eight original clips. The coat shader preserves the original painted eyes and the server's full and partial hues. The worn item determines whether the animal shows its saddle and reins.

| Native body | Worn item | Native identity |
| --- | --- | --- |
| 116 | `0x3EA7` | Nightmare, Unholy Steed |
| 178 | `0x3EA9` | Nightmare |
| 179 | `0x3EB7` | Nightmare |
| 190 | `0x3E9E` | Fire Steed |

Run `python -B scripts/prepare-dark-horse-mounts.py --models "<private Third Dawn Models directory>" --install` using the prepared Godot console. The script reads the named models, atlases, donor clips and model table only after verifying their SHA-256 fingerprints. Generated files go under `work/creatures/dark-horses-bake` and the two packed scenes install under `Viewer/local-art/mounts`. Use `--check-installed` to verify the local manifest. The original archives, generated scenes and screenshots stay private.

The client adds a 1.67-second fire-breath motion to the original rig. It responds to the stock five-frame forward selector. The stock projectile launches from the animated muzzle. Both clients observed launches around 1.3 seconds and damage after the projectile. Controlled targeting invoked the stock ability, including its original timers.

The normal client passed 96 Enhanced and 20 Classic checks. Both rider rigs passed 2,400 checks over 432 poses. A ground offset preserves the original hoof poses. It passed 1,296 supported living poses and 36 fall transfers on three finite planes, with a largest measured handoff displacement of 0.62 µm. The tests cover both corpse packet orders and late hue replication.

The 195-check isolated native pass covers mounted movement, full and partial dyes, dismount, recoil and cadavers across eight rider variants. It also includes four Unholy Steed cases with native oath, allowed riding and refusal for both human rigs. The 71-check isolated native ability pass uses all three stock Nightmare body outcomes and the Fire Steed. The exact Enhanced archive payloads for the Nightmare remain unlocated, so this profile uses Third Dawn motion and the authored breath. Third Dawn's body 177 is an additional table entry. The pinned server's stock Nightmare constructor selects bodies 116, 178 and 179.
