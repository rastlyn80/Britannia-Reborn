extends SceneTree

const ART := "res://local-art/creatures/khaldun_doom/"
const INPUT := ART + "restless-soul-comparison-library.gltf"
const OUTPUT := ART + "restless-soul-on-foot-review.scn"
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const FIT := "res://../work/creatures/mul-motion-review/ghost-registration-fit.json"
const HOOD := "res://../work/creatures/mul-motion-review/ghost-hood-fit.json"

# Classic slot, review clip, source donor, number of registered frames.
const RECIPES := {
	6: ["GhostFidgetBreath", "Idle", 5],
	7: ["GhostReadyOneHand", "Combatidle1h", 1],
	8: ["GhostReadyTwoHand", "Combatadvance_2h", 1],
	9: ["GhostFittedOneHand", "GhostSlashOneHand", 7],
	12: ["GhostFittedDown", "GhostBashTwoHand", 7],
	13: ["GhostFittedWide", "GhostSlashTwoHand", 7],
	14: ["GhostFittedJab", "GhostPierceTwoHand", 7],
	15: ["GhostWarWalk", "Combatadvance_2h", 10],
	16: ["GhostDirectedBend", "GhostCastDirected", 7],
	17: ["GhostAreaReach", "GhostCastArea", 7],
	18: ["GhostDrawBow", "Attackbow", 7],
	19: ["GhostFireCrossbow", "Attackbow", 7],
	30: ["GhostTurnCheck", "GhostTurn", 5],
	31: ["GhostAdvanceStrike", "Combatadvance_1h", 7],
	32: ["GhostLowerBow", "Bow_Lesser", 5],
	33: ["GhostGreeting", "Salute_Greeting", 5],
	34: ["GhostChestFidget", "Applaud", 5],
}

func _initialize() -> void:
	create_timer(50).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var importer := GLTFDocument.new()
	var state := GLTFState.new()
	assert(importer.append_from_file(INPUT, state) == OK)
	var model := importer.generate_scene(state)
	root.add_child(model)
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var space := model.find_child("SourceSpace", true, false) as Node3D
	var space_rest := space.transform
	var fit: Dictionary = {}
	var hood: Dictionary = {}
	if "--fit" in OS.get_cmdline_user_args():
		fit = JSON.parse_string(FileAccess.get_file_as_string(FIT))
	if "--hood" in OS.get_cmdline_user_args():
		hood = JSON.parse_string(FileAccess.get_file_as_string(HOOD))
	var skin := Ground.skin_points(mesh, rig)
	player.deterministic = true
	var target := player.get_node(player.root_node)
	var rig_path := str(target.get_path_to(rig))
	var space_path := target.get_path_to(space)
	var library := player.get_animation_library("")
	for slot: int in RECIPES:
		var recipe: Array = RECIPES[slot]
		var clip := Animation.new()
		clip.length = float(recipe[2]) * 0.16
		var root_track := add_track(clip, Animation.TYPE_POSITION_3D, space_path)
		var facing_track := add_track(clip, Animation.TYPE_ROTATION_3D, space_path)
		var tracks: Array = []
		for bone in rig.get_bone_count():
			var path := NodePath(rig_path + ":" + rig.get_bone_name(bone))
			tracks.append([add_track(clip, Animation.TYPE_POSITION_3D, path),
				add_track(clip, Animation.TYPE_ROTATION_3D, path), add_track(clip, Animation.TYPE_SCALE_3D, path)])
		player.stop()
		player.play(recipe[1], 0.0)
		player.advance(0.0)
		var maximum_lift := 0.0
		for frame in 49:
			var phase := float(frame) / 48.0
			var source_phase := donor_phase(slot, phase)
			space.transform = space_rest
			rig.reset_bone_poses()
			player.seek(source_phase * player.current_animation_length, true)
			rig.force_update_all_bone_transforms()
			shape(slot, rig, phase)
			if hood.has(str(slot)):
				fit_hood(rig, hood[str(slot)], phase)
				if slot == 16:
					gather_hands(rig, sin(PI * phase) ** 2)
			if fit.has(str(slot)):
				assert(fit[str(slot)].clip == recipe[0] and fit[str(slot)].transforms.size() == recipe[2])
				apply_fit(space, fit[str(slot)].transforms, phase)
			var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
			var lift := maxf(0.0, 0.004 - gap)
			maximum_lift = maxf(maximum_lift, lift)
			var time := phase * clip.length
			var correction := space.get_parent_node_3d().global_basis.inverse() * (Vector3.UP * lift)
			clip.position_track_insert_key(root_track, time, space.position + correction)
			clip.rotation_track_insert_key(facing_track, time, space.basis.get_rotation_quaternion())
			for bone in rig.get_bone_count():
				clip.position_track_insert_key(tracks[bone][0], time, rig.get_bone_pose_position(bone))
				clip.rotation_track_insert_key(tracks[bone][1], time, rig.get_bone_pose_rotation(bone))
				clip.scale_track_insert_key(tracks[bone][2], time, rig.get_bone_pose_scale(bone))
		assert(library.add_animation(recipe[0], clip) == OK)
		print("GHOST ON FOOT ", slot, " ", recipe[0], " nominal floor lift ", maximum_lift)
	player.stop(true)
	player.play("Idle", 0.0)
	player.advance(0.0)
	player.stop(true)
	var scene := PackedScene.new()
	assert(scene.pack(model) == OK)
	assert(ResourceSaver.save(scene, OUTPUT, ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()
	quit()

func apply_fit(space: Node3D, transforms: Array, phase: float) -> void:
	var sample := phase * (transforms.size() - 1)
	var first := floori(sample)
	var second := mini(first + 1, transforms.size() - 1)
	var before: Array = transforms[first]
	var after: Array = transforms[second]
	var a := Vector4(before[0], before[1], before[2], before[3])
	var b := Vector4(after[0], after[1], after[2], after[3])
	var pose := a.lerp(b, sample - first)
	var rotation := Basis(Vector3.UP, pose.w)
	var current := space.global_transform
	space.global_transform = Transform3D(rotation * current.basis,
		rotation * current.origin + Vector3(pose.x, pose.y, pose.z))

func fit_hood(rig: Skeleton3D, points: Array, phase: float) -> void:
	var sample := phase * (points.size() - 1)
	var first := floori(sample)
	var before: Array = points[first]
	var after: Array = points[mini(first + 1, points.size() - 1)]
	var target := Vector3(before[0], before[1], before[2]).lerp(Vector3(after[0], after[1], after[2]), sample - first)
	target -= Vector3.UP * 0.105
	var head := rig.find_bone("bip01 head")
	for _iteration in 5:
		for name: String in ["bip01 spine", "bip01 spine1", "bip01 spine2"]:
			var joint := rig.find_bone(name)
			var pivot := rig.get_bone_global_pose(joint).origin
			var current := rig.get_bone_global_pose(head).origin - pivot
			var desired := rig.to_local(target) - pivot
			var aim := Quaternion(current.normalized(), desired.normalized())
			rotate_global(rig, joint, Quaternion.IDENTITY.slerp(aim, 0.30))

func gather_hands(rig: Skeleton3D, weight: float) -> void:
	var chest := rig.to_global(rig.get_bone_global_pose(rig.find_bone("bip01 spine2")).origin)
	for side: String in ["l", "r"]:
		var prefix := "bip01 " + side
		var upper := rig.find_bone(prefix + " upperarm")
		var elbow := rig.find_bone(prefix + " forearm")
		var hand := rig.find_bone(prefix + " hand")
		var shoulder := rig.to_global(rig.get_bone_global_pose(upper).origin)
		var outward := signf(shoulder.x - chest.x)
		var elbow_target := chest + Vector3(outward * 0.20, -0.14, 0.10)
		var hand_target := chest + Vector3(outward * 0.065, -0.09, 0.27)
		aim_at(rig, upper, elbow, elbow_target, weight * 0.88)
		aim_at(rig, elbow, hand, hand_target, weight * 0.9)

func aim_at(rig: Skeleton3D, bone: int, child: int, target: Vector3, influence: float) -> void:
	var pivot := rig.get_bone_global_pose(bone).origin
	var current := rig.get_bone_global_pose(child).origin - pivot
	var desired := rig.to_local(target) - pivot
	var aim := Quaternion(current.normalized(), desired.normalized())
	rotate_global(rig, bone, Quaternion.IDENTITY.slerp(aim, influence))

func add_track(clip: Animation, kind: Animation.TrackType, path: NodePath) -> int:
	var track := clip.add_track(kind)
	clip.track_set_path(track, path)
	return track

func donor_phase(slot: int, phase: float) -> float:
	match slot:
		7:
			return 0.95
		8:
			return 23.0 / 24.0
		15:
			return lerpf(0.21, 0.86, phase)
		30:
			return 0.27 * sin(PI * phase)
		32:
			return lerpf(0.08, 0.82, phase)
		33:
			return lerpf(0.05, 0.56, phase)
		34:
			return lerpf(0.46, 0.88, phase)
	return phase

func shape(slot: int, rig: Skeleton3D, phase: float) -> void:
	var pulse := sin(PI * phase) ** 2
	match slot:
		6:
			turn(rig, "bip01 spine2", Vector3.RIGHT, 0.07 * pulse)
			turn(rig, "bip01 neck", Vector3.RIGHT, -0.13 * pulse)
			turn(rig, "bip01 l upperarm", Vector3.FORWARD, 0.13 * pulse)
			turn(rig, "bip01 r upperarm", Vector3.FORWARD, -0.13 * pulse)
		16:
			turn(rig, "bip01 spine", Vector3.RIGHT, -0.35 * pulse)
			turn(rig, "bip01 spine1", Vector3.RIGHT, -0.19 * pulse)
			turn(rig, "bip01 neck", Vector3.RIGHT, -0.10 * pulse)
		19:
			turn(rig, "bip01 spine2", Vector3.UP, 0.21 * pulse)
			turn(rig, "bip01 r upperarm", Vector3.RIGHT, 0.37 * pulse)
			turn(rig, "bip01 r forearm", Vector3.UP, -0.27 * pulse)
			turn(rig, "bip01 l forearm", Vector3.UP, 0.12 * pulse)
		30:
			turn(rig, "bip01 spine1", Vector3.RIGHT, -0.25 * pulse)
			turn(rig, "bip01 neck", Vector3.RIGHT, -0.14 * pulse)
		31:
			turn(rig, "bip01 spine", Vector3.UP, -0.24 * pulse)
			turn(rig, "bip01 r upperarm", Vector3.RIGHT, -0.52 * pulse)
			turn(rig, "bip01 r forearm", Vector3.UP, -0.25 * pulse)
		32:
			turn(rig, "bip01 spine", Vector3.RIGHT, -0.34 * pulse)
			turn(rig, "bip01 spine2", Vector3.RIGHT, -0.27 * pulse)
			turn(rig, "bip01 neck", Vector3.RIGHT, -0.08 * pulse)

func turn(rig: Skeleton3D, name: String, world_axis: Vector3, amount: float) -> void:
	var bone := rig.find_bone(name)
	assert(bone >= 0)
	var axis := (rig.global_basis.inverse() * world_axis).normalized()
	rotate_global(rig, bone, Quaternion(axis, amount))

func rotate_global(rig: Skeleton3D, bone: int, rotation: Quaternion) -> void:
	var pose := rig.get_bone_global_pose(bone)
	pose.basis = Basis(rotation) * pose.basis
	rig.set_bone_global_pose(bone, pose)
	rig.force_update_all_bone_transforms()
