extends "res://../scripts/bake-zombie-actions.gd"

func run() -> void:
	bake_body(26, "wraith-distinct", {
		2: "Death", 6: "OverheadRake", 15: "ReachingRecoil", 16: "RaisedGuard", 18: "SpectralClutch"
	}, ["bake-wraith-distinct-actions.gd", "bake-zombie-actions.gd"])
	quit()

func add_retained_actions(player: AnimationPlayer, _rig: Skeleton3D, _row: Dictionary, _treatment: String) -> void:
	var library := player.get_animation_library("")
	library.rename_animation("Death", "RecoveredDeath")
	assert(library.add_animation("Death2", library.get_animation("RecoveredDeath").duplicate(true)) == OK)

func pose_troll(rig: Skeleton3D, slot: int, phase: float) -> void:
	var pulse := smoothstep(0.04, 0.39, phase) * (1.0 - smoothstep(0.55, 1.0, phase))
	var response := smoothstep(0.19, 0.53, phase) * (1.0 - smoothstep(0.61, 0.99, phase))
	if slot == 2:
		var fall := smoothstep(0.08, 0.87, phase)
		turn_world(rig, "bip01", Vector3.RIGHT, -1.48 * fall)
		turn_world(rig, "bip01 spine1", Vector3.RIGHT, -0.19 * fall)
		turn_world(rig, "bip01 head", Vector3.RIGHT, 0.20 * fall)
		turn_world(rig, "bip01 l upperarm", Vector3.FORWARD, 0.76 * fall)
		turn_world(rig, "bip01 r upperarm", Vector3.FORWARD, -0.52 * fall)
		turn_world(rig, "bip01 tail", Vector3.RIGHT, 0.40 * fall)
		turn_world(rig, "bip01 tail1", Vector3.RIGHT, -0.33 * fall)
		var drape := smoothstep(0.31, 0.96, phase)
		for chain: Array in [["ponytail1", "ponytail11", "ponytail12", "ponytail13", "ponytail14"],
			["ponytail2", "ponytail21", "ponytail22", "ponytail23", "ponytail24"], ["tail", "tail1", "tail2", "tail3"]]:
			for i in range(chain.size() - 1):
				drape_segment(rig, "bip01 " + chain[i], "bip01 " + chain[i + 1], drape)
		turn_world(rig, "bip01 tail3", Vector3.RIGHT, 0.85 * drape)
		return
	if slot == 6:
		turn_world(rig, "bip01 spine1", Vector3.RIGHT, -0.28 * pulse + 0.38 * response)
		turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, -1.35 * pulse)
		turn_world(rig, "bip01 r forearm", Vector3.RIGHT, -0.37 * pulse + 0.43 * response)
		turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -0.48 * response)
		turn_world(rig, "bip01 tail1", Vector3.RIGHT, -0.61 * pulse)
		return
	if slot == 18:
		for side: String in ["l", "r"]:
			turn_world(rig, "bip01 " + side + " upperarm", Vector3.RIGHT, -0.35 * pulse)
			turn_world(rig, "bip01 " + side + " forearm", Vector3.RIGHT, -0.62 * response)
		turn_world(rig, "bip01 head", Vector3.RIGHT, 0.33 * response)
		return
	var raised := slot == 16
	var side := "l" if raised else "r"
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, (-0.24 if raised else -0.12) * pulse)
	turn_world(rig, "bip01 " + side + " upperarm", Vector3.RIGHT, (-0.79 if raised else -0.55) * pulse)
	turn_world(rig, "bip01 " + side + " forearm", Vector3.RIGHT, (-0.85 if raised else -0.22) * pulse)
	turn_world(rig, "bip01 tail1", Vector3.RIGHT, (0.24 if raised else -0.17) * pulse)

func drape_segment(rig: Skeleton3D, parent_label: String, child_label: String, weight: float) -> void:
	var parent := rig.find_bone(parent_label)
	var child := rig.find_bone(child_label)
	var pose := rig.get_bone_global_pose(parent)
	var direction := (rig.get_bone_global_pose(child).origin - pose.origin).normalized()
	var vertical := (rig.global_basis.inverse() * Vector3.UP).normalized()
	var horizontal := direction.slide(vertical)
	if horizontal.length_squared() < 0.0001:
		horizontal = rig.global_basis.inverse() * Vector3.FORWARD
	var toward_floor := Quaternion(direction, horizontal.normalized())
	pose.basis = Basis(Quaternion.IDENTITY.slerp(toward_floor, weight)) * pose.basis
	rig.set_bone_global_pose(parent, pose)
	rig.force_update_all_bone_transforms()
