extends "res://../scripts/test-gargoyle-kitsune-larva-corpses.gd"

const Efreet := preload("res://../scripts/test-efreet-actions.gd")

func run() -> void:
	Efreet.install_efreet()
	for index in SLOPES.size():
		var plane := await support(SLOPES[index])
		witness(plane, Efreet.EFREET, 12, 0.0, HEIGHTS[index])
		for phase: float in [0.08, 0.45, 0.78]:
			for group: int in [2, 3]:
				witness(plane, Efreet.EFREET, group, phase, HEIGHTS[index])
		plane.free()
		await physics_frame
	assert(handoffs == 21 and checked == 861)
	print("EFREET: ", handoffs, " decoded hover-to-corpse handoffs across ", checked, " poses")
	quit()

func expected_fall(_body: int, group: int) -> String:
	return "Death2" if group == 3 else "Death"
