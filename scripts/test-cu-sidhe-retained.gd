extends "res://Presentation/CuSidheRidingTests.gd"

const SealedBase := preload("res://Presentation/SealedCreatureActionBase.gd")

func run() -> void:
	var active := Registry.entry(277)
	assert(active.classic_gesture_batch == "lattice_through_meer_actions")
	Registry.entries[277] = SealedBase.retained(active, 277)
	await super.run()
