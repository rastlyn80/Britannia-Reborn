extends "res://../scripts/test-gargoyle-kitsune-larva-corpses.gd"

const Batch := preload("res://../scripts/test-avenger-rotting-actions.gd")

func run() -> void:
	Batch.install_routes()
	for tilt: Vector3 in SLOPES:
		var plane := await support(tilt)
		witness(plane, 152, 18, 0.0)
		witness(plane, 155, 11, 0.0)
		for phase: float in [0.08, 0.45, 0.78]:
			for group: int in [2, 3]:
				witness(plane, 152, group, phase)
				witness(plane, 155, group, phase)
		plane.free()
		await physics_frame
	assert(handoffs == 42 and checked == 1722)
	print("TERATHAN AVENGER AND ROTTING CORPSE: ", handoffs, " decoded corpse handoffs across ", checked, " poses")
	quit()

func expected_fall(body: int, group: int) -> String:
	return "Death2" if body == 155 and group == 2 else super.expected_fall(body, group)

func skinned_points(actor: Node3D) -> PackedVector3Array:
	if actor.native_body == 155 and not actor.dead and actor.current_clip == "ArmsRaise":
		for tick in 12:
			actor._physics_process(1.0 / 30.0)
			actor.contact._process_modification_with_delta(1.0 / 30.0)
		actor.support_control_plane()
	return super.skinned_points(actor)
