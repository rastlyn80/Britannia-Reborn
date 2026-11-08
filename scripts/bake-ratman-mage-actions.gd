extends "res://../scripts/bake-ophidian-bardiche.gd"

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Exact := preload("res://../scripts/test-quadruped-actions.gd")
const SWORD_INPUT := "res://../work/creatures/ratman-mage-sword/"
const BLADE := "RatmanSword"
const GESTURES := {11:"MageStoop",15:"MageBladeRise",16:"MageBladeBrace",18:"MageGuardLook"}
const JOINTS := ["bip01 spine", "bip01 spine1", "bip01 head", "bip01 r upperarm", "bip01 r forearm", "bip01 l upperarm"]
const SwordClearance := preload("res://../scripts/ratman-sword-clearance.gd")

func run() -> void:
	var row := Registry.entry(143)
	var assets: Dictionary = row.classic_gesture_base_assets if row.get("classic_gesture_batch") == "ratman_lava_actions" else row.assets
	var scenes := {}
	for treatment: String in ["original", "rounded", "modern"]:
		var path: String = assets[treatment]
		var target := "res://local-art/creatures/ratman-mage-actions-%s.scn" % treatment
		bake_mage(path, target, treatment)
		scenes[treatment] = {"source": FileAccess.get_sha256(path), "scene": FileAccess.get_sha256(target)}
	var inputs := {}
	for name: String in ["bake-ratman-mage-actions.gd", "ratman-sword-clearance.gd", "bake-ophidian-bardiche.gd",
			"bake-skeleton-axe-trial.gd", "bake-troll-weapons-trial.gd", "test-quadruped-actions.gd"]:
		inputs[name] = FileAccess.get_sha256("res://../scripts/" + name)
	inputs["corners.json"] = FileAccess.get_sha256(SWORD_INPUT + "corners.json")
	inputs["atlas.png"] = FileAccess.get_sha256(SWORD_INPUT + "atlas.png")
	var receipt := FileAccess.open(SWORD_INPUT + "bake.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"inputs": inputs, "scenes": scenes}))
	receipt.close()
	quit()

func bake_mage(path: String, target: String, treatment: String) -> void:
	var model := (load(path) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var grip := rig.find_bone("cp_grasp_rhand")
	assert(grip >= 0)
	player.play("Idle", 0.0)
	player.advance(0.0)
	player.seek(0.0, true)
	rig.force_update_all_bone_transforms()
	var socket := rig.global_transform * rig.get_bone_global_pose(grip)
	var tip := Vector3(-0.10, 0.15, 1.0).normalized()
	var blade_basis := Basis(Quaternion(Vector3.UP, (socket.basis.inverse() * tip).normalized()))
	var bone := rig.add_bone("ratman sword")
	rig.set_bone_parent(bone, grip)
	rig.set_bone_rest(bone, Transform3D(blade_basis, Vector3.ZERO))
	rig.reset_bone_pose(bone)
	var sword := make_sword()
	var skin := Skin.new()
	skin.add_bind(bone, Transform3D.IDENTITY)
	sword.skin = skin
	sword.skeleton = NodePath("..")
	rig.add_child(sword)
	sword.owner = model
	var body := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	assert(body != sword)
	var solver := SwordClearance.new(body, rig)
	var points: PackedVector3Array = sword.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
	player.remove_animation_library("")
	player.add_animation_library("", library)
	for clip: String in player.get_animation_list():
		assert(library.add_animation("Recovered" + clip, library.get_animation(clip).duplicate(true)) == OK)
		fit_sword(player, rig, grip, bone, points, solver, clip)
	var body_skin := Ground.skin_points(body, rig)
	for group: int in GESTURES:
		var clip: String = GESTURES[group]
		assert(library.add_animation(clip, make_gesture(player, rig, body_skin, group)) == OK)
		fit_sword(player, rig, grip, bone, points, solver, clip)
	var sword_skin := Ground.skin_points(sword, rig)
	var gaps := {}
	for clip: String in player.get_animation_list():
		if clip.begins_with("Recovered"):
			continue
		player.stop()
		player.play(clip, 0.0)
		player.advance(0.0)
		var gap := INF
		var conflicts := 0
		for frame in 61:
			player.seek(player.current_animation_length * frame / 60.0, true)
			rig.force_update_all_bone_transforms()
			gap = minf(gap, Ground.minimum_plane_gap(sword_skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
			assert(rig.get_bone_global_pose(bone).origin.is_equal_approx(rig.get_bone_global_pose(grip).origin))
			if frame % 3 == 0:
				solver.update_pose()
				conflicts += int(solver.intersects(rig.global_transform * rig.get_bone_global_pose(bone)))
		gaps[clip] = [gap, conflicts]
	Exact.check_earlier_keys(player, path)
	player.stop()
	var packed := PackedScene.new()
	assert(packed.pack(model) == OK and ResourceSaver.save(packed,
		target, ResourceSaver.FLAG_COMPRESS) == OK)
	print("RATMAN MAGE ", treatment, " fixed sword socket, earlier keys exact, floor gaps ", gaps)
	model.free()

func make_gesture(player: AnimationPlayer, rig: Skeleton3D, skin: Dictionary, group: int) -> Animation:
	var base := player.get_animation("RecoveredIdle")
	var result := base.duplicate(true) as Animation
	result.length = 0.44 if group in [15,16] else 0.79
	result.loop_mode = Animation.LOOP_NONE
	var path := player.get_node(player.root_node).get_path_to(rig)
	for track in result.get_track_count():
		for key in range(result.track_get_key_count(track) - 1, 0, -1):
			result.track_remove_key(track, key)
	var channels := {}
	for name: String in JOINTS:
		var joint := rig.find_bone(name)
		assert(joint >= 0, name)
		var track_path := NodePath("%s:%s" % [path, name])
		var track := result.find_track(track_path, Animation.TYPE_ROTATION_3D)
		if track < 0:
			track = result.add_track(Animation.TYPE_ROTATION_3D)
			result.track_set_path(track, track_path)
		channels[joint] = track
	var placement := NodePath("%s:bip01" % path)
	var position := result.find_track(placement, Animation.TYPE_POSITION_3D)
	if position < 0:
		position = result.add_track(Animation.TYPE_POSITION_3D)
		result.track_set_path(position, placement)
	var root_joint := rig.find_bone("bip01")
	player.stop()
	player.play("RecoveredIdle", 0.0)
	player.advance(0.0)
	for frame in 81:
		var phase := float(frame) / 80.0
		rig.reset_bone_poses()
		player.seek(0.0, true)
		rig.force_update_all_bone_transforms()
		pose_mage(rig, group, phase)
		var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
		var placement_pose := rig.get_bone_global_pose(root_joint)
		placement_pose.origin += rig.global_basis.inverse() * Vector3.UP * (0.003 - gap)
		rig.set_bone_global_pose(root_joint, placement_pose)
		var time := result.length * phase
		result.position_track_insert_key(position, time, rig.get_bone_pose_position(root_joint))
		for joint: int in channels:
			result.rotation_track_insert_key(channels[joint], time, rig.get_bone_pose_rotation(joint))
	return result

func pose_mage(rig: Skeleton3D, group: int, phase: float) -> void:
	var pulse := smoothstep(0.04,0.40,phase) * (1.0-smoothstep(0.59,1.0,phase))
	var stoop := group == 11
	var guard := group == 16
	mage_turn(rig, "bip01 spine", Vector3.RIGHT, (0.32 if stoop else -0.07) * pulse)
	mage_turn(rig, "bip01 spine1", Vector3.UP, (0.28 if guard else -0.12) * pulse)
	mage_turn(rig, "bip01 head", Vector3.UP, (0.34 if group == 18 else 0.10) * pulse)
	mage_turn(rig, "bip01 r upperarm", Vector3.RIGHT, (-0.67 if group == 15 else 0.16) * pulse)
	mage_turn(rig, "bip01 r forearm", Vector3.UP, (0.62 if guard else -0.14) * pulse)
	mage_turn(rig, "bip01 l upperarm", Vector3.FORWARD, 0.16 * pulse)

func mage_turn(rig: Skeleton3D, name: String, axis: Vector3, angle: float) -> void:
	rotate_joint(rig, rig.find_bone(name), Quaternion((rig.global_basis.inverse() * axis).normalized(), angle))

func fit_sword(player: AnimationPlayer, rig: Skeleton3D, grip: int, blade: int,
		points: PackedVector3Array, solver: RefCounted, clip: String) -> void:
	var motion := player.get_animation(clip)
	var rest := rig.get_bone_rest(blade)
	var path := player.get_node(player.root_node).get_path_to(rig)
	var intervals := ceili(motion.length * 120.0)
	var fitted: Array[Quaternion] = []
	player.stop()
	player.play(clip, 0.0)
	player.advance(0.0)
	for frame in intervals + 1:
		player.seek(motion.length * float(frame) / intervals, true)
		rig.force_update_all_bone_transforms()
		var socket := rig.global_transform * rig.get_bone_global_pose(grip)
		var desired := socket * rest
		if clip == "Walk":
			var carry := Vector3(-0.28, 0.58, 0.76).normalized().slerp(desired.basis.y.normalized(), 0.14)
			desired.basis = Basis(Quaternion(Vector3.UP, carry)).scaled_local(socket.basis.get_scale())
		var pose := settle_weapon(desired, points, 0.015, true)
		pose.origin = socket.origin
		solver.update_pose()
		var previous := socket.basis * Basis(fitted.back()) if not fitted.is_empty() else pose.basis
		pose = fit_body(pose, previous, points, solver, 0.03, 0.012)
		fitted.append((socket.basis.inverse() * pose.basis).orthonormalized().get_rotation_quaternion())
	player.stop()
	var track := motion.add_track(Animation.TYPE_ROTATION_3D)
	motion.track_set_path(track, NodePath("%s:ratman sword" % path))
	for frame in fitted.size():
		motion.rotation_track_insert_key(track, motion.length * float(frame) / intervals, fitted[frame])

func make_sword() -> MeshInstance3D:
	var corners: Array = JSON.parse_string(FileAccess.get_file_as_string(SWORD_INPUT + "corners.json"))
	assert(corners.size() == 240)
	var atlas := Image.load_from_file(SWORD_INPUT + "atlas.png")
	assert(atlas != null and not atlas.is_empty())
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(atlas)
	material.roughness = 0.64
	material.metallic = 0.66
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	builder.set_material(material)
	for point: Array in corners:
		vertex(builder, Vector3(-point[1], point[0], point[2]),
			Vector3(-point[4], point[3], point[5]), Vector2(point[6], point[7]))
	var prop := MeshInstance3D.new()
	prop.name = BLADE
	prop.mesh = builder.commit()
	prop.material_override = material
	return prop
