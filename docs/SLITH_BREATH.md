# Slith fire breath

Slith and Toxic Slith share body 734. The server gives the two classes Fire Breath and supplies their native hues. Stone Slith shares their rig and sends its own attacks and effects. The client selects breath only for the stock five-frame forward Classic group 12 cue.

Classic previously played its compatibility attack for that cue. The added motion uses the retained Komodo rig and idle animation, with new head, neck and jaw keys. Enhanced keeps its fitted breath clip. Both modes keep an active breath pose through Classic groups 4–6 and Enhanced melee type 0. The projectile uses a snout point fitted against Forward+ captures in both profiles. Melee resumes after the windup and death can interrupt it.

Classic and Enhanced World replays each passed eight checks for timing, melee resumption, delayed effect placement and the matching dyed static corpse. Run the replay with Godot `--headless --path Viewer --script res://../scripts/test-slith-breath-world.gd`. Add `-- --enhanced-creature-actions` for Enhanced.

In a separate trial the native AI selected Fire Breath against a fixture-positioned target for both creatures in both modes. It sent ordinary melee packets 710–1,020 ms into the windup. All four fireballs left the displayed snout 1,300–1,307 ms after windup and the native server reduced the target's health in every case. Each mode passed 18 checks. Wild encounter placement and a closer match for the donor's colour and surface remain open. [Rig and existing action evidence](ENHANCED_REPTILE_VARIANTS.md)
