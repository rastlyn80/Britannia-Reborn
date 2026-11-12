# Ratman footing and corpse transitions

The existing Third Dawn Ratman rigs now adapt their feet, tail, head and visible equipment to slopes and adjacent treads. Walk and Run blend the mismatched ends of the original motion near the seam. Movement can interrupt a standing fidget or guard look. Attacks keep their existing timing and routing.

Body 42 keeps its Classic unarmed appearance and the separate Enhanced axe fit. Historical Classic bodies 44 and 45 keep their existing identities. The native Archer is body 142 with the recovered Third Dawn bow. Ratman Mage and Chiikkaha share body 143 and retain their own stock constructors. Their sword and the optional Enhanced crook follow the pose when visible.

Both client profiles passed 3,180 moving poses on the 22 cm tread. The measured minimum visible skin or weapon clearance was about 3 mm. The worst loop-seam displacement fell from 40 cm in the axe Ratman to 7 cm on the tread, with a 9 cm maximum across all five bodies. Whole-model clearance corrections peaked at 26 mm. A hand can still move abruptly by 26 cm between two samples at the high tread.

The client passed 256 transfers from moving, fitted or already falling poses and 4,352 sampled collapse frames. The first pose changed by less than 4 micrometres in the test and the frozen static corpse kept the original body, hue and visible equipment. The actual native Archer death still removes the worn bow, as the server requests.

The isolated ModernUO run passed 109 checks in each profile with two clients. It covered stock Ratman, Ratman Archer, Ratman Mage and Chiikkaha, exact body and dye, walking and running, the native bow projectile, and the final frozen corpse. The terrain fixture is a separate client check on flat ground, a slope and a 22 cm ledge. The live run uses the stock world.

Reproduce the moving and collapse checks with Godot headless, `--path Viewer --script res://../scripts/test-ratman-living-crossing.gd` and `res://../scripts/test-ratman-living-fall.gd`. Repeat with `-- --enhanced-creature-actions` for the optional profile. The verifier runs both when the locally prepared Ratman, Mage and bow are present. Source assets and preparation are recorded in [Ratman and lizardman source forms](RATMEN_AND_LIZARDMEN.md) and [Ratman Archer](RATMAN_ARCHER.md).
