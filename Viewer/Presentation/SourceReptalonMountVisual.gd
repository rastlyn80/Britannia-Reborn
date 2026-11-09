extends "res://Presentation/SourceRigMountVisual.gd"


func mount_fittings() -> Dictionary:
	return {
		"proportions": Vector3.ONE,
		# Start at the original rider marker and offset aft for wing clearance.
		"saddle": Vector3(0.0, 2.11, -1.80),
		"mouth": Vector3(0.0, 2.01, 2.04),
		"seat_bone": "spine1",
		"mouth_bone": "head",
		"stirrup": Vector3(0.43, -0.59, 0.15),
	}
