extends "res://../scripts/test-spider-mongbat-gestures.gd"

func forms() -> Dictionary:
	return {
		48: {"clip": "ClawDraw", "support": ["bip01 r toe0", "bip01 l toe0", "bone_hind01", "bone_hind06"],
			"moving": "bip01 r finger0", "minimum_travel": 0.8, "alpha": "scorpions_giant-original-albedo.png"},
		74: {"clip": "WingTwitch", "support": ["bip01 r toe0", "bip01 l toe0"],
			"moving": "imp_l_wing 02", "minimum_travel": 0.015, "maximum_travel": 0.20,
			"actions": {11: "WingTwitch", 17: "WingTwitch", 18: "Fidget2"},
			"alpha": "imps_imp-original-albedo.png"},
	}

func check_motion(actor: Node3D, body: int, treatment: String) -> bool:
	if not super.check_motion(actor, body, treatment):
		return false
	if body == 74:
		var primary: Animation = actor.animator.get_animation("WingTwitch")
		var alias: Animation = actor.animator.get_animation("Fidget2")
		assert(primary.length == alias.length and primary.get_track_count() == alias.get_track_count())
		for i in primary.get_track_count():
			assert(primary.track_get_path(i) == alias.track_get_path(i))
			assert(primary.get("tracks/%d/keys" % i) == alias.get("tracks/%d/keys" % i))
		return true
	var rig: Skeleton3D = actor.skeleton
	var player: AnimationPlayer = actor.animator
	var start := pose_points(player, rig, 0.0)
	var dip := pose_points(player, rig, 0.29)
	var held := pose_points(player, rig, 0.79)
	print(treatment, " tail dip / recovered height / late right and left claw draw ",
		[start[2].y - dip[2].y, held[2].y - start[2].y, start[0].z - held[0].z, start[1].z - held[1].z])
	return (start[2].y - dip[2].y > 0.15 and absf(held[2].y - start[2].y) < 0.03
		and start[0].z - held[0].z > 0.45 and start[1].z - held[1].z > 0.3)

func pose_points(player: AnimationPlayer, rig: Skeleton3D, phase: float) -> PackedVector3Array:
	player.seek(player.get_animation("ClawDraw").length * phase, true)
	rig.force_update_all_bone_transforms()
	var points := PackedVector3Array()
	for name in ["bip01 r finger0", "bip01 l finger0", "bip01 tail4"]:
		points.append(rig.to_global(rig.get_bone_global_pose(rig.find_bone(name)).origin))
	return points
