extends "res://Presentation/SourceRigMountVisual.gd"


func mount_fittings() -> Dictionary:
	return {
		"proportions": Vector3.ONE,
		"saddle": Vector3(0.0, 1.91, 0.45),
		"mouth": Vector3(0.0, 1.82, 2.19),
		"seat_bone": "spine",
		"mouth_bone": "head",
		"stirrup": Vector3(0.42, -0.60, 0.12),
	}
