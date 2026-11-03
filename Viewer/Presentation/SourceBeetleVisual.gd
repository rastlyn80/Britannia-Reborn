extends "res://Presentation/SourceRigMountVisual.gd"
## Fit the saddle over the original shell and guide the reins to the head.
func mount_fittings() -> Dictionary:
	return {
		"proportions": Vector3(.39, .60, .60),
		"saddle": Vector3(0., 2.94, .34),
		"mouth": Vector3(0., 1.78, 2.15),
		"seat_bone": "pelvis",
		"mouth_bone": "head",
		"stirrup": Vector3(.48, -.57, .11),
	}
