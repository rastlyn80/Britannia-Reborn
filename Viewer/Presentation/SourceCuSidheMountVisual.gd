extends "res://Presentation/SourceRigMountVisual.gd"


func mount_fittings() -> Dictionary:
	return {
		"proportions": Vector3.ONE,
		"saddle": Vector3(0.0, 1.96, -0.18),
		"mouth": Vector3(0.0, 1.46, 1.72),
		"seat_bone": "spine1",
		"mouth_bone": "head",
		"stirrup": Vector3(0.43, -0.59, 0.15),
	}
