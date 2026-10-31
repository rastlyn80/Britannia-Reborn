# Dungeons, cave entrances and death (31 October 2026)

Owner request: dungeons looked like open air, mountain entrances were not openings, and death left the normal world and an ordinary body. The 2D client hides all this with isometric darkness; the 3D client now follows what top-down 3D games do: underground space has no sky, a closing black, a light carried by the player, and walls that rise into darkness.

## Underground

`Viewer/Presentation/Underground.gd` reads the converted map directly (BRW chunks, no extra data):

- **Underground land:** UO marks underground space with its black void land (0x244) and cave land. On Trammel there are 1.7 million void tiles in the dungeon strip and only 166 on the surface (the cave mouths themselves).
- **Being underground:** the player is underground when such land lies within 12 tiles (at least 6 hits on a 2-tile grid) or underfoot, and outdoors again only when none lies within 18 tiles. The presentation eases over 1.5 s.
- **Lighting** (`LightingRig.set_underground`), blended from the outdoor values:
  - no sun and no sky (black background);
  - a dim cool ambient;
  - black depth fog from 9 m, closed at 46 m;
  - a warm carried light (17 m, flickering, shadowed) above the player.
- **Cave terrain:** districts with at least 48 void/cave tiles draw their terrain with `CaveGround.gdshader` instead of the outdoor ground: wet rock on slopes; grey grit, flagstones (stone land) or moss (grass land) on flat ground. Everything more than about 1.4–3.6 m above the player's feet fades to black, so cave walls rise into darkness instead of ending on the void plateau.

The swap happens when a district is shown (`LiveDistricts.dresser`). The baked cache is unchanged, and positions and movement are untouched.

## Cave entrances

Every mountain entrance on Trammel's surface (29 of them: Covetous, Shame, Deceit, Wrong, Destard, Despise, Hythloth, the mines…) is marked by a cluster of blank-art blocker tiles (0x3B60–0x3B83) laid on the ground before it.

For each cluster, `Underground.entrances()`:
1. walks up the terrain gradient to the foot of the rise and faces the opening downhill;
2. sizes it to the cluster: 2.6–4.6 m wide, 2.3–3.4 m tall;
3. builds an arched rock frame, tunnel walls that darken with depth and a black back wall.

The heightfield cannot be hollowed, so `CaveMouth.gdshader` depth-tests the opening as if it lay on the mouth's own plane, pulled 1.4 m toward the camera. The hillside around it never hides it, while a mountain between the camera and the entrance still does. Checked from the front, the side and behind the mountain at Covetous.

The blockers had no rule and were drawn as small placeholder cubes. `RegionalRules` now makes them invisible; this takes effect when the districts holding them are next baked.

## Death

- **Ghost body:** ghost bodies 0x192/0x193 are the same human body (sex preserved) instead of the fallback figure. `HumanAvatar.set_ghostly()` makes every mesh translucent with no shadow and adds `Ghost.gdshader`: a pale veil, brightest at the silhouette, with a slow rising shimmer. Resurrection restores each mesh's own transparency, overlay and shadow setting.
- **Black and white:** `DeathScreen.dead_changed` drives `LightingRig.set_dead`, which drains the world to black and white over 1.6 s, with a little more contrast. Colour returns over 1 s on resurrection. The interface keeps its colours.
- **Testing:** Esc → Developer → Die / Resurrect calls the loopback-only `[PreviewDie` / `[PreviewResurrect`, which are ModernUO's own `Kill()` and `Resurrect()`.

## Checks

- `UndergroundTests` (in `scripts/verify.ps1`), on synthetic chunks: underground detection and hysteresis, cave districts, entrance placement and facing, opening geometry, ghost bodies, the underground and death lighting, and death screen signals.
- GPU renders: Covetous level 1 (dark cave, carried light, rock walls fading up into darkness), the Covetous entrance (front, side, behind), and a living character beside a ghost, in colour and when dead.

## Remaining gaps

- Cave walls are only about 3 m high in the source map (cave land 13–16 z above the floor). They read as low ridges under the darkness; taller terrain is the separate mountain work.
- Built dungeons (stone halls with void behind wall statics) use the same darkness; their walls are statics and keep their own models.
- The placeholder cubes on entrance blockers remain until those districts are rebaked.
