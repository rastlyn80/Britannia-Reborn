extends "res://../scripts/bake-classic-gesture-trials.gd"

const STEM := "res://local-art/creatures/ettins_ettin"
const JOINTS := ["bip01 l upperarm", "bip01 l forearm", "geosphere01", "geosphere02"]

func run() -> void:
	var scenes := {}
	for treatment: String in ["original", "rounded", "modern"]:
		var source := "%s-%s.gltf" % [STEM, treatment]
		var model := (load(source) as PackedScene).instantiate()
		root.add_child(model)
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		for label: String in ["EttinTempleCheck", "Fidget2"]:
			var clip := gesture(player, rig, label == "EttinTempleCheck")
			assert(player.get_animation_library("").add_animation(label, clip) == OK)
		player.stop()
		var scene := PackedScene.new()
		assert(scene.pack(model) == OK)
		var output := "%s-fidgets-%s.scn" % [STEM, treatment]
		assert(ResourceSaver.save(scene, output, ResourceSaver.FLAG_COMPRESS) == OK)
		scenes[treatment] = {"source": FileAccess.get_sha256(source), "scene": FileAccess.get_sha256(output)}
		model.free()
	var receipt := FileAccess.open("res://../work/creatures/mul-motion-review/ettin-fidgets-bake.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"recipe": FileAccess.get_sha256(get_script().resource_path),
		"aim_solver": FileAccess.get_sha256("res://../scripts/bake-classic-gesture-trials.gd"), "scenes": scenes}))
	receipt.close()
	print("ETTIN: separate temple and chest fidgets on three source skins")
	quit()

func gesture(player: AnimationPlayer, rig: Skeleton3D, temple: bool) -> Animation:
	var idle := player.get_animation("Idle")
	var clip := idle.duplicate(true) as Animation
	clip.length = 1.04 if temple else 0.88
	clip.loop_mode = Animation.LOOP_NONE
	var tracks := {}
	for track in clip.get_track_count():
		var value: Variant = idle.track_get_key_value(track, 0)
		for key in range(clip.track_get_key_count(track) - 1, -1, -1):
			clip.track_remove_key(track, key)
		clip.track_insert_key(track, 0.0, value)
		var name := str(clip.track_get_path(track).get_concatenated_subnames())
		if clip.track_get_type(track) == Animation.TYPE_ROTATION_3D and name in JOINTS:
			tracks[rig.find_bone(name)] = track
	assert(tracks.size() == JOINTS.size() and not tracks.has(-1))
	for frame in 73:
		var phase := float(frame) / 72.0
		var amount := smoothstep(0.02, 0.26, phase) * (1.0 - smoothstep(0.53 if temple else 0.41, 1.0, phase))
		player.play("Idle", 0.0)
		player.advance(0.0)
		player.seek(0.0, true)
		rig.force_update_all_bone_transforms()
		if amount > 0.0:
			pose_heads(rig, amount, temple)
			var head := rig.find_bone("geosphere02")
			var origin := rig.to_global(rig.get_bone_global_pose(head).origin)
			var goal := origin + (Vector3(0.34, 0.11, 0.48) if temple else Vector3(-0.23, -0.51, 0.66))
			aim_left_hand(rig, rig.to_local(goal), amount)
		for bone: int in tracks:
			clip.rotation_track_insert_key(tracks[bone], phase * clip.length, rig.get_bone_pose_rotation(bone))
	return clip

func pose_heads(rig: Skeleton3D, amount: float, temple: bool) -> void:
	var axis := (rig.global_basis.inverse() * Vector3.UP).normalized()
	for head: String in ["geosphere01", "geosphere02"]:
		var bone := rig.find_bone(head)
		var pose := rig.get_bone_global_pose(bone)
		var angle := -0.16 if head == "geosphere01" else (0.13 if temple else -0.07)
		pose.basis = Basis(Quaternion(axis, angle * amount)) * pose.basis
		rig.set_bone_global_pose(bone, pose)

func aim_left_hand(rig: Skeleton3D, goal: Vector3, amount: float) -> void:
	var shoulder := rig.find_bone("bip01 l upperarm")
	var elbow := rig.find_bone("bip01 l forearm")
	var hand := rig.find_bone("bip01 l hand")
	var a := rig.get_bone_global_pose(shoulder).origin
	var b := rig.get_bone_global_pose(elbow).origin
	var c := rig.get_bone_global_pose(hand).origin
	var target := c.lerp(goal, amount)
	var direction := (target - a).normalized()
	var upper := a.distance_to(b)
	var lower := b.distance_to(c)
	var distance := clampf(a.distance_to(target), absf(upper - lower) + 0.001, upper + lower - 0.001)
	var along := (upper * upper - lower * lower + distance * distance) / (2.0 * distance)
	var outside := (rig.global_basis.inverse() * Vector3(0.85, -0.55, 0.08)).normalized()
	var pole := outside.slide(direction).normalized()
	var bend := a + direction * along + pole * sqrt(maxf(0.0, upper * upper - along * along))
	aim(rig, shoulder, elbow, bend)
	aim(rig, elbow, hand, target)
