# Bull terrain and corpses

The two stock Bull bodies, 232 and 233, keep their original rigs, coats and motion sources. The terrain renderer grounds the hooves on slopes and on separate treads while preserving the server position. Moving interrupts idle fidgets. The Classic collapses and the optional Enhanced fall preserve the displayed pose and settle onto the ground before the corpse freezes.

The client passed 13,000 living poses and 312 collapse handoffs across the two profiles. The minimum living clearance was 2.994 mm. The largest joint displacement at the start of a handoff was below 3.5 micrometres. The two client replays covered the original cow tipping and recovery, distinct Bull collapse silhouettes and late corpse dye.

Two isolated clients passed 80 native checks across both bodies, both stock hues and both player sexes. Stock movement, wrestling, recoil, taming and corpse packets drove the normal client paths. Repeated native skill gains exposed an expired notification reference. The client now recreates an evicted card when the next gain arrives, with a regression test in the existing polish suite.

Run `scripts/verify.ps1` with the prepared cattle assets to reproduce the client checks. Original archive contents, derived scenes, review images and native test receipts remain local.
