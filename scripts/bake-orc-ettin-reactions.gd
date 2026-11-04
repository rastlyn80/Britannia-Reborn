extends "res://../scripts/bake-classic-gesture-trials.gd"

const STEMS := {17: "orcs_orc", 18: "ettins_ettin"}
const ARM_JOINTS := ["bip01 r upperarm", "bip01 r forearm", "bip01 l upperarm", "bip01 l forearm"]
const ART := "res://local-art/creatures/"

func run() -> void:
	var scenes := {}
	for body: int in STEMS:
		var treatments := {}
		for treatment: String in ["original", "rounded", "modern"]:
			treatments[treatment] = bake_reaction_scene(body, treatment)
		scenes[str(body)] = treatments
	var receipt := FileAccess.open(ART + "orc-ettin-reactions-bake.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"recipe": FileAccess.get_sha256(get_script().resource_path),
		"solver": FileAccess.get_sha256("res://../scripts/bake-classic-gesture-trials.gd"), "scenes": scenes}))
	receipt.close()
	print("ORC AND ETTIN REACTIONS: four authored clips across six accepted source scenes")
	quit()

func bake_reaction_scene(body: int, treatment: String) -> Dictionary:
	var stem := ART + str(STEMS[body])
	var source := "%s-fidgets-%s.scn" % [stem, treatment]
	var output := "%s-reactions-%s.scn" % [stem, treatment]
	var model := (load(source) as PackedScene).instantiate()
	root.add_child(model)
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for side: String in ["RightRecoil", "LeftRecoil"]:
		var clip := build_reaction(player, rig, body, side == "RightRecoil")
		assert(player.get_animation_library("").add_animation(side, clip) == OK)
	player.stop()
	var scene := PackedScene.new()
	assert(scene.pack(model) == OK)
	assert(ResourceSaver.save(scene, output, ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()
	return {"source": FileAccess.get_sha256(source), "scene": FileAccess.get_sha256(output)}

func build_reaction(player: AnimationPlayer, rig: Skeleton3D, body: int, right: bool) -> Animation:
	var clip := player.get_animation("Idle").duplicate(true) as Animation
	clip.length = 0.48
	clip.loop_mode = Animation.LOOP_NONE
	var heads := ["bip01 head"] if body == 17 else ["geosphere01", "geosphere02"]
	var names := ARM_JOINTS + ["bip01 spine1", "bip01 spine2"] + heads
	var tracks := {}
	for track in clip.get_track_count():
		for key in range(clip.track_get_key_count(track) - 1, 0, -1):
			clip.track_remove_key(track, key)
		if clip.track_get_type(track) == Animation.TYPE_ROTATION_3D:
			var name := str(clip.track_get_path(track).get_concatenated_subnames())
			if name in names:
				tracks[name] = track
	assert(tracks.size() == names.size())
	for sample in 49:
		var phase := float(sample) / 48.0
		var amount := smoothstep(0.03, 0.44, phase) * (1.0 - smoothstep(0.54, 1.0, phase))
		player.play("Idle", 0.0)
		player.advance(0.0)
		player.seek(0.0, true)
		rig.force_update_all_bone_transforms()
		if amount > 0.0:
			pose_reaction(rig, heads, body, right, amount)
		for name: String in tracks:
			clip.rotation_track_insert_key(tracks[name], phase * clip.length, rig.get_bone_pose_rotation(rig.find_bone(name)))
	return clip

func pose_reaction(rig: Skeleton3D, heads: Array, body: int, right: bool, amount: float) -> void:
	var yaw := -0.22 if right else 0.43
	var tuck := 0.30 if right else 0.24
	rotate(rig, "bip01 spine1", Vector3.RIGHT, tuck * amount)
	rotate(rig, "bip01 spine2", Vector3.UP, yaw * amount)
	var top := Vector3.ZERO
	for name: String in heads:
		rotate(rig, name, Vector3.RIGHT, (0.11 if right else 0.24) * amount)
		top += rig.to_global(rig.get_bone_global_pose(rig.find_bone(name)).origin)
	top /= float(heads.size())
	if right:
		var reach := Vector3(-0.72, 0.10, 0.47) if body == 17 else Vector3(-0.08, 0.13, 0.57)
		place_hand(rig, "r", top + reach, amount)
		if body == 18:
			place_hand(rig, "l", top + Vector3(0.32, -0.55, 0.60), amount)
	else:
		var reach := Vector3(-0.12, -0.36, 0.63) if body == 17 else Vector3(-0.23, -0.30, 0.72)
		place_hand(rig, "l", top + reach, amount)
		if body == 18:
			place_hand(rig, "r", top + Vector3(-0.75, -0.73, 0.55), amount)

func rotate(rig: Skeleton3D, name: String, axis: Vector3, angle: float) -> void:
	var bone := rig.find_bone(name)
	var pose := rig.get_bone_global_pose(bone)
	var direction := (rig.global_basis.inverse() * axis).normalized()
	pose.basis = Basis(Quaternion(direction, angle)) * pose.basis
	rig.set_bone_global_pose(bone, pose)
	rig.force_update_all_bone_transforms()

func place_hand(rig: Skeleton3D, side: String, world_target: Vector3, amount: float) -> void:
	var shoulder := rig.find_bone("bip01 %s upperarm" % side)
	var elbow := rig.find_bone("bip01 %s forearm" % side)
	var hand := rig.find_bone("bip01 %s hand" % side)
	var a := rig.get_bone_global_pose(shoulder).origin
	var b := rig.get_bone_global_pose(elbow).origin
	var c := rig.get_bone_global_pose(hand).origin
	var target := c.lerp(rig.to_local(world_target), amount)
	var direction := (target - a).normalized()
	var upper := a.distance_to(b)
	var lower := b.distance_to(c)
	var distance := clampf(a.distance_to(target), absf(upper - lower) + 0.001, upper + lower - 0.001)
	var along := (upper * upper - lower * lower + distance * distance) / (2.0 * distance)
	var outside := (rig.global_basis.inverse() * Vector3(-0.85 if side == "r" else 0.85, -0.45, 0.22)).normalized()
	var pole := outside.slide(direction).normalized()
	var bend := a + direction * along + pole * sqrt(maxf(0.0, upper * upper - along * along))
	aim(rig, shoulder, elbow, bend)
	aim(rig, elbow, hand, target)
