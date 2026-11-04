extends "res://../scripts/bake-mongbat-actions.gd"

const Exact := preload("res://../scripts/test-quadruped-actions.gd")
const HARPY_DONOR := "res://local-art/creatures/harpy-air-death-donor.gltf"
const FITS := {4: "RaisedWingKick", 6: "WingRush", 15: "WingTuckRecoil",
	16: "WideWingRecoil", 18: "FeatherFlick"}

func run() -> void:
	var scenes := {}
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	assert(document.append_from_file(HARPY_DONOR, state) == OK)
	var donor := document.generate_scene(state)
	root.add_child(donor)
	var row := Registry.entry(30)
	assert(row.classic_action_categories["11"] == "Wingbeat")
	for treatment: String in row.assets:
		var source := Registry.asset_path(row, treatment)
		bake_harpy(source, treatment, donor)
		var target := "res://local-art/creatures/harpy-actions-%s.scn" % treatment
		scenes[treatment] = {"source": FileAccess.get_sha256(source), "scene": FileAccess.get_sha256(target)}
	donor.free()
	var inputs := {}
	for file: String in [get_script().resource_path, "res://../scripts/bake-mongbat-actions.gd",
		"res://../scripts/bake-troll-actions.gd",
		"res://../scripts/bake-skeleton-actions.gd",
		"res://Presentation/WaterElementalFidgets.gd",
		"res://Presentation/SourceGroundLookup.gd",
		"res://local-art/creatures/harpy-air-death-donor.gltf"]:
		inputs[file.get_file()] = FileAccess.get_sha256(file)
	var receipt := FileAccess.open("res://local-art/creatures/harpy-actions-bake.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"inputs": inputs, "scenes": scenes}))
	receipt.close()
	quit()

func bake_harpy(path: String, treatment: String, donor: Node3D) -> void:
	var model := (load(path) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var donor_rig := donor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	assert(rig.get_bone_count() == 34 and rig.get_bone_count() == donor_rig.get_bone_count())
	for bone in rig.get_bone_count():
		assert(rig.get_bone_name(bone) == donor_rig.get_bone_name(bone))
		assert(rig.get_bone_parent(bone) == donor_rig.get_bone_parent(bone))
		assert(rig.get_bone_rest(bone).is_equal_approx(donor_rig.get_bone_rest(bone)))
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(mesh, rig)
	var skins: Array[Dictionary] = [skin]
	var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
	player.remove_animation_library("")
	player.add_animation_library("", library)
	player.deterministic = true
	add_air_death(player, rig, skin, donor)
	refine_air_clearance(player, rig, skin)
	assert(library.add_animation("Death2", grounded_fall(player, rig, skin)) == OK)
	for slot: int in FITS:
		assert(library.add_animation(FITS[slot], fit_troll(player, rig, skins, slot)) == OK)
	Exact.check_earlier_keys(player, path)
	player.play("AirDeath", 0.0)
	player.advance(0.0)
	var initial := clearance(skin, rig)
	var least := initial
	for frame in 481:
		player.seek(player.current_animation_length * frame / 480.0, true)
		least = minf(least, clearance(skin, rig))
	var ending := clearance(skin, rig)
	print(treatment, " AirDeath track count, duration, initial/min/final skin gap ",
		[player.get_animation("AirDeath").get_track_count(), player.current_animation_length, initial, least, ending])
	assert(initial > 0.50 and least > -0.012 and absf(ending - 0.004) < 0.001)
	player.stop()
	var packed := PackedScene.new()
	var target := "res://local-art/creatures/harpy-actions-%s.scn" % treatment
	assert(packed.pack(model) == OK and ResourceSaver.save(packed, target, ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()

func refine_air_clearance(player: AnimationPlayer, rig: Skeleton3D, skin: Dictionary) -> void:
	var motion := player.get_animation("AirDeath")
	var root_bone := rig.find_bone("bip01")
	var path := NodePath(str(player.get_node(player.root_node).get_path_to(rig)) + ":bip01")
	var track := motion.find_track(path, Animation.TYPE_POSITION_3D)
	assert(track >= 0)
	var dense := PackedVector3Array()
	player.play("AirDeath", 0.0)
	player.advance(0.0)
	for frame in 1201:
		player.seek(motion.length * frame / 1200.0, true)
		var gap := clearance(skin, rig)
		var pose := rig.get_bone_global_pose(root_bone)
		pose.origin += rig.global_basis.inverse() * Vector3.UP * maxf(0.0, 0.004 - gap)
		rig.set_bone_global_pose(root_bone, pose)
		dense.append(rig.get_bone_pose_position(root_bone))
	for key in range(motion.track_get_key_count(track) - 1, -1, -1):
		motion.track_remove_key(track, key)
	for frame in dense.size():
		motion.position_track_insert_key(track, motion.length * frame / 1200.0, dense[frame])
	player.stop()

func pose_troll(rig: Skeleton3D, slot: int, phase: float) -> void:
	var pulse := smoothstep(0.04, 0.41, phase) * (1.0 - smoothstep(0.59, 0.99, phase))
	var flap := sin(TAU * phase) * pulse
	if slot == 18:
		feather(rig, "l", 0.48 * flap, 0.14 * pulse)
		feather(rig, "r", 0.44 * flap, -0.14 * pulse)
		turn_world(rig, "bip01 head", Vector3.UP, 0.20 * pulse)
		return
	if slot in [15, 16]:
		var narrow := slot == 15
		feather(rig, "l", (-0.55 if narrow else 0.24) * pulse, (0.28 if narrow else -0.22) * pulse)
		feather(rig, "r", (0.22 if narrow else 0.62) * pulse, (-0.21 if narrow else 0.34) * pulse)
		turn_world(rig, "bip01 spine1", Vector3.UP, (0.23 if narrow else -0.28) * pulse)
		turn_world(rig, "bip01 head", Vector3.RIGHT, -0.28 * pulse)
		return
	var kick := slot == 4
	feather(rig, "l", (0.61 if kick else -0.37) * pulse, 0.31 * pulse)
	feather(rig, "r", (0.80 if kick else -0.45) * pulse, -0.31 * pulse)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, (-0.14 if kick else 0.38) * pulse)
	turn_world(rig, "bip01 l thigh", Vector3.RIGHT, -0.59 * pulse)
	turn_world(rig, "bip01 l calf", Vector3.RIGHT, (0.26 if kick else 0.51) * pulse)
	turn_world(rig, "bip01 head", Vector3.RIGHT, 0.16 * pulse)

func feather(rig: Skeleton3D, side: String, pitch: float, sweep: float) -> void:
	var sign := 1.0 if side == "l" else -1.0
	turn_world(rig, "bip01 " + side + " upperarm", Vector3.FORWARD, sign * pitch)
	turn_world(rig, "bip01 " + side + " forearm", Vector3.UP, sign * sweep)
	turn_world(rig, "bip01 " + side + " hand", Vector3.FORWARD, -sign * pitch * 0.46)
