# Hell Cat and Predator Hellcat fire breath

The ordinary Hell Cat shares body 201 with other cats. The six stock Hell Cat hues and the exact five-frame group 12 cue select fire breath. The ordinary cat keeps its collapse. Predator Hellcat has its own body 127 and selects the breath by body and the same native cue. Administrative recolours outside the stock hues on body 201 require another way to identify the Hell Cat.

The client builds the 1.58-second motion on each creature's existing idle, adding neck and head movement while leaving the paws supported. The firebolt originates from the skinned muzzle at the server's launch time. Overlapping melee requests preserve the windup, and death still interrupts it. Neither current rig has a jaw joint. The two motion fits use the existing muzzle geometry and do not add a jaw.

The body 201 fit retains the licensed Quaternius mesh and rig described in [the cat evidence](CAT_TERRAIN.md). Body 127 retains the Third Dawn model, atlas, and compatible Panther idle from the local accepted index.

| Third Dawn member | SHA-256 |
| --- | --- |
| `uotdb/uotd/Models/Animals/felines_predator_hellcat_LOD2.grn` | `9adbad4428ac321b74615be07af47e36e6170e64ca64722844620a2a6ab178c8` |
| `uotdb/uotd/Models/Maps/felines_predator_hellcat_v03.tga` | `4bf08240abf9787c4c91afe0135fdf8544e26796d215379d180a3571dff7db2e` |
| `uotdb/uotd/Models/Animals/felines_panther_idle.grn` | `18aa3279e489ef7a244944b2362ae2a1f9888028afc950a4b4a1d0ea4c3ecf0e` |

Stock AI selected fire breath for both classes in the disposable server arena. Classic and Enhanced each passed 18 checks across both classes. The four bolts launched 1,302–1,308 ms after their actual cues, with zero measured muzzle separation and with native melee cues about one second into each windup. Targets lost 4–11 hit points. Both local World profiles passed 15 decoded checks including the normal cat fall and both static corpse handoffs. Forward+ captures confirmed the muzzle anchors. The existing cat World replay also passed in both profiles. Predator Hellcat wild encounters and a dedicated full-skin terrain audit remain open.
