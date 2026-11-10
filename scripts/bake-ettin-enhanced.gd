# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-orc-enhanced.gd"

const TrialFolder := "res://../work/creatures/native-form-audit/enhanced-source-gaps/bird-ettin/"
const Hammer := "ettin enhanced hammer"
const EttinClips := {23: "EttinRise", 28: "EttinAlert"}
const EttinLengths := {23: .8, 28: .6}

func run() -> void:
	var row := Registry.entry(18)
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(TrialFolder + "ettin-hammer-atlas.png"))
	material.roughness = .82
	var corners: Array = JSON.parse_string(FileAccess.get_file_as_string(TrialFolder + "ettin-hammer-corners.json"))
	assert(corners.size() == 204)
	for treatment: String in row.assets:
		var source := Registry.asset_path(row, treatment)
		assert(FileAccess.get_sha256(source) == row.asset_sha256[treatment])
		bake_ettin(source, treatment, corners, material)
	quit()

func bake_ettin(source: String, treatment: String, corners: Array, material: Material) -> void:
	var model := (load(source) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
	player.remove_animation_library("")
	player.add_animation_library("", library)
	var joint := rig.add_bone(Hammer)
	var grip := rig.find_bone("cp_grasp_rhand")
	assert(grip >= 0)
	rig.set_bone_parent(joint, grip)
	rig.set_bone_rest(joint, Transform3D(Basis.IDENTITY, Vector3(0, .06, 0)))
	rig.reset_bone_pose(joint)
	var hammer := add_hammer(rig, model, joint, corners, material)
	var skins: Array[Dictionary] = []
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		skins.append(Ground.skin_points(mesh, rig))
	var joints := Joints.filter(func(bone: String): return rig.find_bone(bone) >= 0)
	joints.append_array(["bip01 neck", "geosphere01", "geosphere02", Hammer])
	var earlier := player.get_animation_list()
	for group: int in EttinClips:
		var action := fit_grounded(player, rig, skins, EttinLengths[group], "bip01", joints, pose_ettin.bind(group), .008)
		assert(library.add_animation(EttinClips[group], action) == OK)
	Exact.check_earlier_keys(player, source)
	var death := library.get_animation("Death")
	assert(library.add_animation("RecoveredDeath", death.duplicate(true)) == OK)
	for name: String in earlier:
		bake_hammer_carry(player, rig, hammer, joint, name, skins[0])
	player.stop()
	rig.reset_bone_poses()
	var scene := PackedScene.new()
	assert(scene.pack(model) == OK)
	assert(ResourceSaver.save(scene, TrialFolder + "ettin-%s.scn" % treatment, ResourceSaver.FLAG_COMPRESS) == OK)
	print("ETTIN ENHANCED ", treatment, ": retained two-head rig and original hammer with two fitted motions")
	model.free()

func add_hammer(rig: Skeleton3D, model: Node, joint: int, corners: Array, material: Material) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	for data: Array in corners:
		var broadening := 1.0 + .40 * smoothstep(.30, .55, float(data[1]))
		var point := Vector3(float(data[0]) * broadening, data[1], float(data[2]) * broadening) * 1.8
		surface.set_normal(Vector3(float(data[3]) / broadening, data[4], float(data[5]) / broadening).normalized())
		surface.set_uv(Vector2(data[6], data[7]))
		surface.set_bones(PackedInt32Array([0, 0, 0, 0]))
		surface.set_weights(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
		surface.add_vertex(point)
	var mesh := MeshInstance3D.new()
	mesh.name = "EnhancedHammer"
	mesh.mesh = surface.commit()
	mesh.skin = Skin.new()
	mesh.skin.add_bind(joint, Transform3D.IDENTITY)
	mesh.skeleton = NodePath("..")
	rig.add_child(mesh)
	mesh.owner = model
	return mesh

func bake_hammer_carry(player: AnimationPlayer, rig: Skeleton3D, hammer: MeshInstance3D,
		joint: int, name: String, body_skin: Dictionary) -> void:
	var clip := player.get_animation(name)
	var track := clip.add_track(Animation.TYPE_ROTATION_3D)
	var path := player.get_node(player.root_node).get_path_to(rig)
	clip.track_set_path(track, NodePath("%s:%s" % [path, Hammer]))
	if name not in ["Death", "Death2", "LieDown"]:
		clip.rotation_track_insert_key(track, 0.0, Quaternion.IDENTITY)
		return
	var skin := Ground.skin_points(hammer, rig)
	var rotations: Array[Quaternion] = []
	var arm_samples: Array[Array] = []
	var arm := PackedInt32Array()
	for bone: String in ["bip01 r upperarm", "bip01 r forearm", "bip01 r hand"]:
		arm.append(rig.find_bone(bone))
	var hand := arm[2]
	var count := maxi(2, ceili(clip.length * 60.0) + 1)
	var max_correction := 0.0
	player.play(name, 0.0)
	player.advance(0.0)
	for i in count:
		player.seek(clip.length * float(i) / (count - 1), true)
		rig.set_bone_pose_rotation(joint, Quaternion.IDENTITY)
		rig.force_update_all_bone_transforms()
		var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
		var weight := 1.0 - smoothstep(.025, .31, gap)
		var pose := rig.global_transform * rig.get_bone_global_pose(joint)
		var outward := pose.origin - joint_world(rig, "bip01 pelvis")
		outward.y = 0.0
		var shaft := (Vector3.RIGHT if outward.length_squared() < .01 else outward).normalized()
		var target := Basis(Vector3.UP, shaft, Vector3.UP.cross(shaft))
		pose.basis = pose.basis.orthonormalized().slerp(target, weight).scaled_local(pose.basis.get_scale())
		rig.set_bone_global_pose(joint, rig.global_transform.affine_inverse() * pose)
		rig.force_update_all_bone_transforms()
		if name == "Death":
			# The old forward fall lowers the held hammer below the body. Bend
			# only the armed elbow and preserve the hand's world orientation.
			var hand_pose := rig.get_bone_global_pose(hand)
			var hand_origin := rig.to_global(hand_pose.origin)
			var body_floor := Ground.minimum_plane_gap(body_skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
			var weapon_floor := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
			var rise := maxf(0.0, body_floor + .025 - weapon_floor)
			if rise > .001:
				fit_arm(rig, "r", hand_origin + Vector3.UP * rise)
				var lifted := rig.get_bone_global_pose(hand)
				lifted.basis = hand_pose.basis
				rig.set_bone_global_pose(hand, lifted)
				rig.force_update_all_bone_transforms()
				max_correction = maxf(max_correction, hand_origin.distance_to(rig.to_global(lifted.origin)))
			var arm_keys: Array[Quaternion] = []
			for bone in arm:
				arm_keys.append(rig.get_bone_pose_rotation(bone))
			arm_samples.append(arm_keys)
		rotations.append(rig.get_bone_pose_rotation(joint))
	player.stop()
	for i in count:
		clip.rotation_track_insert_key(track, clip.length * float(i) / (count - 1), rotations[i])
	if name == "Death":
		for index in arm.size():
			var arm_path := NodePath("%s:%s" % [path, rig.get_bone_name(arm[index])])
			var arm_track := clip.find_track(arm_path, Animation.TYPE_ROTATION_3D)
			assert(arm_track >= 0)
			for key in range(clip.track_get_key_count(arm_track) - 1, -1, -1):
				clip.track_remove_key(arm_track, key)
			for i in count:
				clip.rotation_track_insert_key(arm_track, clip.length * float(i) / (count - 1), arm_samples[i][index])
		print("ETTIN FORWARD FALL: maximum grip correction ", max_correction, " m")

func pose_ettin(rig: Skeleton3D, phase: float, group: int) -> void:
	var rise := smoothstep(.1, .92, phase)
	var dip := sin(PI * smoothstep(0.0, .60, phase))
	var spread := sin(PI * smoothstep(.25, 1.0, phase))
	var crouch := .62 * (1.0 - rise) if group == 23 else .18 * dip
	var lean := .78 * (1.0 - rise) if group == 23 else .26 * dip
	var hips := rig.find_bone("bip01")
	var root_pose := rig.get_bone_global_pose(hips)
	root_pose.origin += rig.global_basis.inverse() * Vector3(0.0, -crouch, -.23 * crouch)
	rig.set_bone_global_pose(hips, root_pose)
	rig.force_update_all_bone_transforms()
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .65 * lean)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .35 * lean)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, -.15 * lean)
	turn_world(rig, "geosphere01", Vector3.UP, -.17 * spread)
	turn_world(rig, "geosphere02", Vector3.UP, .13 * spread)
	for side: String in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		var foot := rig.find_bone("bip01 %s foot" % side)
		var target := rig.get_bone_global_pose(foot)
		target.origin = rig.to_local(Vector3(sign_x * .48, .24, .19 if side == "l" else -.13))
		fit_foot(rig, side, target)
	var pelvis := joint_world(rig, "bip01 pelvis")
	var right := Vector3(-.65, -.36, .24)
	var left := Vector3(.64, -.39, .26)
	var shaft := Vector3(-.40, -.70, .43)
	if group == 23:
		right += Vector3(.20, -.20, .62) * (1.0 - rise)
		left += Vector3(-.18, -.16, .59) * (1.0 - rise)
		shaft = Vector3(-.43, .05, .88).lerp(shaft, rise)
	else:
		right += Vector3(-.35, .89, .23) * spread + Vector3(.16, -.17, .37) * dip
		left += Vector3(.78, 1.0, .34) * spread + Vector3(-.11, -.20, .39) * dip
		shaft = shaft.lerp(Vector3(-.74, .57, .34), spread)
	fit_arm(rig, "r", pelvis + right)
	fit_arm(rig, "l", pelvis + left)
	var joint := rig.find_bone(Hammer)
	var pose := rig.get_bone_global_pose(joint)
	var direction := (rig.global_basis.inverse() * shaft).normalized()
	pose.basis = Basis(Quaternion(pose.basis.y.normalized(), direction)) * pose.basis
	rig.set_bone_global_pose(joint, pose)
	rig.force_update_all_bone_transforms()
