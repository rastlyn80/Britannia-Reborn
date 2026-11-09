extends "res://../scripts/test-gargoyle-kitsune-larva-corpses.gd"

const Workers := preload("res://../scripts/test-solen-worker-actions.gd")

func run() -> void:
	Workers.install_worker_routes()
	for tilt: Vector3 in SLOPES:
		var plane := await support(tilt)
		for body: int in Workers.WORKERS:
			witness(plane, body, 15, 0.0)
			for phase: float in [0.08, 0.45, 0.78]:
				for group: int in [2, 3]:
					witness(plane, body, group, phase)
		plane.free()
		await physics_frame
	assert(handoffs == 42 and checked == 1722)
	print("SOLEN WORKERS: ", handoffs, " decoded corpse handoffs across ", checked, " poses")
	quit()

func skinned_points(actor: Node3D) -> PackedVector3Array:
	if not actor.dead and actor.current_clip == "WorkerBrace":
		# Run the six-foot modifier before capturing the actual displayed pose.
		for tick in 16:
			actor._physics_process(1.0 / 30.0)
			actor.contact._process_modification_with_delta(1.0 / 30.0)
	return super.skinned_points(actor)
