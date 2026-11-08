extends "res://../scripts/bake-ophidian-bardiche.gd"

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Exact := preload("res://../scripts/test-quadruped-actions.gd")
const MOTIONS := {3:"Death2", 5:"BardicheLowSweep", 6:"BardicheHighChop", 15:"BardicheHighRecoil",
	16:"BardicheLowBrace", 18:"BardicheGripShift"}
const BODY_TRACKS := ["bip01 spine", "bip01 spine1", "bip01 head", "bip01 r upperarm", "bip01 r forearm",
	"bip01 l upperarm", "bip01 tail", "bip01 tail1", "bip01 tail2", "bip01 tail3"]

func run() -> void:
	var row := Registry.entry(86)
	var assets: Dictionary = row.classic_gesture_base_assets if row.get("classic_gesture_batch") == "ophidian_patchwork_actions" else row.assets
	var receipts := {}
	for treatment: String in ["original", "rounded", "modern"]:
		var source: String = assets[treatment]
		var output := "res://local-art/creatures/ophidian-bardiche-actions-%s.scn" % treatment
		bake_actions(source, output)
		receipts[treatment] = {"source": FileAccess.get_sha256(source), "scene": FileAccess.get_sha256(output)}
	var receipt := FileAccess.open("res://local-art/creatures/ophidian-bardiche-actions-bake.json", FileAccess.WRITE)
	assert(receipt != null)
	var inputs := {}
	for name: String in ["bake-ophidian-bardiche-actions.gd", "bake-ophidian-bardiche.gd", "bake-skeleton-axe-trial.gd", "bake-troll-weapons-trial.gd", "ophidian-bardiche-clearance.gd"]:
		inputs[name] = FileAccess.get_sha256("res://../scripts/" + name)
	inputs["SourceGroundLookup.gd"] = FileAccess.get_sha256("res://Presentation/SourceGroundLookup.gd")
	receipt.store_string(JSON.stringify({"inputs": inputs, "scenes": receipts}))
	receipt.close()
	quit()

func bake_actions(source: String, output: String) -> void:
	var model := (load(source) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var prop := model.find_child("OphidianBardiche", true, false) as MeshInstance3D
	assert(prop != null, "The fitted action layer requires the reviewed armed scene")
	var points: PackedVector3Array = prop.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var body := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	assert(body != prop)
	var clearance := Clearance.new(body, rig)
	var skin := Ground.skin_points(body, rig)
	var weapon := rig.find_bone(BARDICHE)
	var grip := rig.find_bone("cp_grasp_rhand")
	assert(weapon >= 0 and grip >= 0 and rig.get_bone_parent(weapon) == grip)
	var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
	player.remove_animation_library("")
	player.add_animation_library("", library)
	for slot: int in MOTIONS:
		assert(library.add_animation(MOTIONS[slot], fit_body_motion(player, rig, skin, slot)) == OK)
		fit_clip(player, rig, grip, weapon, points, clearance, MOTIONS[slot])
	Exact.check_earlier_keys(player, source)
	player.stop()
	var scene := PackedScene.new()
	assert(scene.pack(model) == OK and ResourceSaver.save(scene,
		output, ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()

func fit_body_motion(player: AnimationPlayer, rig: Skeleton3D, skin: Dictionary, slot: int) -> Animation:
	var seed := "Death" if slot == 3 else "Idle"
	var base := player.get_animation(seed)
	var result := base.duplicate(true) as Animation
	result.length = base.length if slot == 3 else (0.43 if slot in [15, 16] else 0.74)
	result.loop_mode = Animation.LOOP_NONE
	var path := player.get_node(player.root_node).get_path_to(rig)
	var tracks := {}
	for name: String in BODY_TRACKS:
		var track := result.find_track(NodePath("%s:%s" % [path, name]), Animation.TYPE_ROTATION_3D)
		assert(track >= 0)
		tracks[rig.find_bone(name)] = track
		for index in range(result.track_get_key_count(track) - 1, -1, -1):
			result.track_remove_key(track, index)
	var root_bone := rig.find_bone("bip01")
	var root_track := result.find_track(NodePath("%s:bip01" % path), Animation.TYPE_POSITION_3D)
	if root_track < 0:
		root_track = result.add_track(Animation.TYPE_POSITION_3D)
		result.track_set_path(root_track, NodePath("%s:bip01" % path))
	for index in range(result.track_get_key_count(root_track) - 1, -1, -1):
		result.track_remove_key(root_track, index)
	player.play(seed, 0.0)
	player.advance(0.0)
	for frame in 121:
		var phase := float(frame) / 120.0
		rig.reset_bone_poses()
		player.seek((phase if slot == 3 else 0.0) * base.length, true)
		rig.force_update_all_bone_transforms()
		pose_body(rig, slot, phase)
		var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
		var root_pose := rig.get_bone_global_pose(root_bone)
		root_pose.origin += rig.global_basis.inverse() * Vector3.UP * (0.003 - gap)
		rig.set_bone_global_pose(root_bone, root_pose)
		result.position_track_insert_key(root_track, phase * result.length, rig.get_bone_pose_position(root_bone))
		for joint: int in tracks:
			result.rotation_track_insert_key(tracks[joint], phase * result.length, rig.get_bone_pose_rotation(joint))
	return result

func pose_body(rig: Skeleton3D, slot: int, phase: float) -> void:
	var drive := smoothstep(0.17, 0.55, phase) * (1.0 - smoothstep(0.61, 0.98, phase))
	var wind := smoothstep(0.01, 0.22, phase) * (1.0 - smoothstep(0.29, 0.64, phase))
	var slump := smoothstep(0.14, 0.91, phase) if slot == 3 else 0.0
	var lower := slot in [5, 6, 16]
	turn(rig, "bip01 spine", Vector3.RIGHT, (0.29 if lower else -0.08) * drive + 0.29 * slump)
	turn(rig, "bip01 spine1", Vector3.UP, (-0.39 if slot == 5 else 0.16) * drive - 0.36 * slump)
	turn(rig, "bip01 head", Vector3.UP, (0.28 if slot == 18 else -0.08) * drive)
	turn(rig, "bip01 r upperarm", Vector3.RIGHT, -0.58 * wind + (0.65 if lower else -0.36) * drive + 0.46 * slump)
	turn(rig, "bip01 r forearm", Vector3.UP, (0.42 if slot == 5 else -0.18) * drive)
	turn(rig, "bip01 l upperarm", Vector3.FORWARD, 0.28 * drive + 0.36 * slump)
	for index in 4:
		var name := "bip01 tail" if index == 0 else "bip01 tail%d" % index
		turn(rig, name, Vector3.UP, (0.13 * drive + 0.19 * slump) * cos(index * 0.5))

func turn(rig: Skeleton3D, name: String, axis: Vector3, angle: float) -> void:
	var joint := rig.find_bone(name)
	assert(joint >= 0)
	rotate_joint(rig, joint, Quaternion((rig.global_basis.inverse() * axis).normalized(), angle))
