# Cow footing, living tip and native milking

The stock ModernUO Cow chooses the spotted body 216 or the brown body 231. Both keep their prepared Third Dawn rig, coat, Classic action routes and optional Enhanced actions. They use the same visual hoof support as the bulls, with extra ground probes that reach the cow's leading hoof before it reaches a higher tread.

The two client modes passed 13,000 sampled terrain poses, 3,000 walking and running poses across a 22 cm ledge, and 32 living tips with 2,624 tip and recovery poses. The sampled skin kept about 3 mm minimum clearance after the correction. The source locomotion can still move a hoof abruptly near the running loop and the largest measured whole-model correction between moving samples was 64 mm.

The living tip keeps its original group 8, zero-frame, three-repeat signature. The cow stays alive, lies down, then stands and resumes movement. Actual deaths continue the displayed fall into a static corpse with the matching body and hue. The client sampled 456 fall transfers and 11,400 collapse poses, including death during the living tip and recovery. The largest measured first-pose change was under 4 micrometres.

The isolated server passed 114 checks in each mode, exercising both coats with both disposable players. It confirmed stock walking, running, tipping, recovery, Animal Taming and the static corpse. Both players used the normal client fill cursor on the Cow. The owner filled a five-unit pitcher and used one native serving. The other player was in range and sight, and the ownership refusal left the pitcher and stock empty. The trial used the already approved local milking correction installed in the tested server build.

Repeat the client checks with Godot headless and `--path Viewer --script res://../scripts/test-cow-living-crossing.gd`. Run `res://../scripts/test-bull-living-fall.gd -- --cows` for the falls. Add `--enhanced` to the script arguments for the optional profile. The tests require the locally prepared cattle assets described in the [bovine progress record](PROGRESS.md). Original game assets and local server receipts remain outside Git.
