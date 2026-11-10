# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const Stage := "res://../work/creatures/native-form-audit/enhanced-source-gaps/orc-shaman-ophidian-mage/"
const Profile := preload("res://Presentation/EnhancedCreatureProfile.gd")
const Clearance := preload("orc-shaman-staff-clearance.gd")
const StaffBone := "orc shaman staff"
const OrcClips := {23: "OrcShamanStaffRise", 28: "OrcShamanStaffBrace"}
const Lengths := {23: 1.23, 28: .69}
const Upright := Vector3(-.20, .97, .12)
const Outward := Vector3(-.74, .21, .64)
const OrcJoints := ["bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 head",
	"bip01 r upperarm", "bip01 r forearm", "bip01 r hand", "bip01 l upperarm", "bip01 l forearm",
	"bip01 l thigh", "bip01 l calf", "bip01 l foot", "bip01 r thigh", "bip01 r calf", "bip01 r foot"]


func run() -> void:
	var row := Registry.entry(140)
	var corners: Array = JSON.parse_string(FileAccess.get_file_as_string(Stage + "orc-shaman-staff-corners.json"))
	assert(corners.size() == 288)
	var points := PackedVector3Array()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(Stage + "orc-shaman-staff-atlas.png"))
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = .12
	material.roughness = .78
	for corner: Array in corners:
		var point := Vector3(corner[0], corner[1], corner[2]) * Clearance.Shape
		points.append(point)
		surface.set_normal((Vector3(corner[3], corner[4], corner[5]) / Clearance.Shape).normalized())
		surface.set_uv(Vector2(corner[6], corner[7]))
		surface.set_bones(PackedInt32Array([0, 0, 0, 0]))
		surface.set_weights(PackedFloat32Array([1, 0, 0, 0]))
		surface.add_vertex(point)
	var mesh := surface.commit()
	for treatment: String in Profile.registered_assets(row):
		bake_treatment(treatment, row, mesh, material, points)
	quit()


func bake_treatment(treatment: String, row: Dictionary, staff_mesh: ArrayMesh,
		material: Material, points: PackedVector3Array) -> void:
	var source := Registry.asset_path(row, treatment)
	assert(FileAccess.get_sha256(source) == row.asset_sha256[treatment])
	var model := (load(source) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var body := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var clearance := Clearance.new(body, rig)
	var skins: Array[Dictionary] = [Ground.skin_points(body, rig)]
	var grip := rig.find_bone("cp_grasp_rhand")
	assert(grip >= 0)
	var joint := rig.add_bone(StaffBone)
	rig.set_bone_parent(joint, grip)
	var prop := MeshInstance3D.new()
	prop.name = "OrcShamanStaff"
	prop.mesh = staff_mesh
	prop.material_override = material
	prop.skin = Skin.new()
	prop.skin.add_bind(joint, Transform3D.IDENTITY)
	prop.skeleton = NodePath("..")
	rig.add_child(prop)
	prop.owner = model
	var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
	player.remove_animation_library("")
	player.add_animation_library("", library)
	var retained := library.get_animation_list()
	var probe := "--rise-probe" in OS.get_cmdline_user_args()
	for group: int in OrcClips:
		if probe and group != 23:
			continue
		var clip: String = OrcClips[group]
		var motion := fit_grounded(player, rig, skins, Lengths[group], "__root", OrcJoints,
			pose_orc.bind(group), .005)
		assert(library.add_animation(clip, motion) == OK)
		fit_staff(player, rig, grip, points, clearance, clip, group)
	verify_base_clips(player, source)
	if not probe:
		for clip: String in retained:
			fit_staff(player, rig, grip, points, clearance, clip)
	player.stop()
	rig.reset_bone_poses()
	var result := PackedScene.new()
	assert(result.pack(model) == OK)
	var name := "140-probe-%s.scn" if probe else "140-%s.scn"
	assert(ResourceSaver.save(result, Stage + name % treatment, ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()


func pose_orc(rig: Skeleton3D, phase: float, group: int) -> void:
	var rise := group == 23
	var crouch := 1.0 - smoothstep(.06, .66, phase) if rise else 0.0
	var raise := envelope(phase, .18, .43, .62, .98) if rise else .49 * smoothstep(.15, .77, phase)
	var lean := .24 * envelope(phase, .10, .50, .68, .95) if not rise else .12 * crouch
	turn_world(rig, "bip01 pelvis", Vector3.RIGHT, .26 * crouch)
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .43 * crouch + .15 * lean)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .43 * crouch)
	turn_world(rig, "bip01 spine2", Vector3.BACK, lean)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.48 * crouch)
	turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, -.70 * raise)
	turn_world(rig, "bip01 r upperarm", Vector3.BACK, -.68 * crouch - .36 * raise)
	turn_world(rig, "bip01 r forearm", Vector3.RIGHT, -.34 * crouch - .75 * raise)
	turn_world(rig, "bip01 r hand", Vector3.UP, .35 * crouch)
	turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -.57 * crouch)
	turn_world(rig, "bip01 l forearm", Vector3.RIGHT, .36 * crouch - .38 * raise)
	for side: String in ["l", "r"]:
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -.64 * crouch)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, 1.02 * crouch)
		turn_world(rig, "bip01 %s foot" % side, Vector3.RIGHT, -.36 * crouch)


func fit_staff(player: AnimationPlayer, rig: Skeleton3D, grip: int, points: PackedVector3Array,
		clearance: RefCounted, clip: String, group: int = -1) -> void:
	var motion := player.get_animation(clip)
	var intervals := maxi(1, ceili(motion.length * 240.0))
	var rotations: Array[Quaternion] = []
	var sockets: Array[Transform3D] = []
	var arm_rotations: Array[Quaternion] = []
	var arm := rig.find_bone("bip01 r upperarm")
	var lifted := 0
	player.stop()
	player.play(clip, 0.0)
	player.advance(0.0)
	for index in intervals + 1:
		var phase := float(index) / intervals
		player.seek(motion.length * phase, true)
		rig.force_update_all_bone_transforms()
		if group < 0 and lift_low_grip(rig, grip, arm):
			lifted += 1
		arm_rotations.append(rig.get_bone_pose_rotation(arm))
		clearance.update_pose()
		var socket := rig.global_transform * rig.get_bone_global_pose(grip)
		var aim := staff_direction(socket, clip, group, phase)
		var picked := choose_rotation(socket, aim, points, clearance)
		assert(picked.is_finite(), "%s staff clearance at %.3f, grip %s" % [clip, phase, socket.origin])
		rotations.append(picked)
		sockets.append(socket)
	var radii := [29, 19, 12, 7, 4] if group == 23 else [12, 7, 4]
	for radius: int in radii:
		var filtered := rotations.duplicate()
		for index in rotations.size():
			var center := rotations[index]
			var average := center
			for offset in range(-radius, radius + 1):
				if offset == 0:
					continue
				var other := rotations[clampi(index + offset, 0, intervals)]
				average += (other if center.dot(other) >= 0.0 else -other) * (1.0 - absf(float(offset)) / (radius + 1))
			var target := average.normalized()
			player.seek(motion.length * index / intervals, true)
			rig.set_bone_pose_rotation(arm, arm_rotations[index])
			rig.force_update_all_bone_transforms()
			clearance.update_pose()
			for weight: float in [1.0, .65, .35, .15]:
				var candidate := center.slerp(target, weight)
				if staff_clearance(sockets[index], candidate, points, clearance, .010):
					filtered[index] = candidate
					break
		rotations = filtered
	player.stop()
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	if lifted > 0:
		var arm_track := motion.find_track(NodePath("%s:bip01 r upperarm" % rig_path), Animation.TYPE_ROTATION_3D)
		assert(arm_track >= 0)
		for key in range(motion.track_get_key_count(arm_track) - 1, -1, -1):
			motion.track_remove_key(arm_track, key)
		for index in arm_rotations.size():
			motion.rotation_track_insert_key(arm_track, motion.length * index / intervals, arm_rotations[index])
	var track := motion.add_track(Animation.TYPE_ROTATION_3D)
	motion.track_set_path(track, NodePath("%s:%s" % [rig_path, StaffBone]))
	for index in rotations.size():
		motion.rotation_track_insert_key(track, motion.length * index / intervals, rotations[index])
	print(clip, " staff fit ", rotations.size(), " poses, arm clearance corrections ", lifted)


func lift_low_grip(rig: Skeleton3D, grip: int, arm: int) -> bool:
	var grip_point := rig.to_global(rig.get_bone_global_pose(grip).origin)
	var deficit := .17 - grip_point.y
	if deficit <= 0.0:
		return false
	var arm_point := rig.to_global(rig.get_bone_global_pose(arm).origin)
	var reach := grip_point - arm_point
	var axis := reach.cross(Vector3.UP).normalized()
	if axis.is_zero_approx():
		return false
	var length := reach.length()
	var base_pitch := asin(clampf(reach.y / length, -.999, .999))
	var target_pitch := asin(clampf((reach.y + deficit * smoothstep(0.0, .035, deficit)) / length, -.999, .999))
	var parent := rig.global_basis * rig.get_bone_global_pose(rig.get_bone_parent(arm)).basis
	var local_axis := (parent.inverse() * axis).normalized()
	var correction := Quaternion(local_axis, target_pitch - base_pitch)
	rig.set_bone_pose_rotation(arm, (correction * rig.get_bone_pose_rotation(arm)).normalized())
	rig.force_update_all_bone_transforms()
	return true


func staff_direction(socket: Transform3D, clip: String, group: int, phase: float) -> Vector3:
	var low := Outward.normalized()
	var high := Upright.normalized()
	var aim := high
	match group:
		23:
			aim = low.slerp(high, smoothstep(.36, .82, phase))
		28:
			aim = high.slerp(low, .44 * smoothstep(.11, .85, phase))
		_:
			if clip == "Death":
				aim = high.slerp(Vector3(-.92, 0, .39).normalized(), smoothstep(.12, .62, phase))
			elif clip in ["Attack", "Attack2", "Attack3", "Cast", "Pillage"]:
				aim = high.slerp(low, .52 * sin(PI * phase))
	var scale := socket.basis.get_scale().length() / sqrt(3.0)
	var floor_space := maxf(0.0, socket.origin.y - .035)
	var height := clampf(aim.y, -floor_space / (1.649 * Clearance.Shape.y * scale),
		floor_space / (.713 * Clearance.Shape.y * scale))
	var horizontal := Vector3(aim.x, 0, aim.z).normalized()
	return horizontal * sqrt(1.0 - height * height) + Vector3.UP * height


func choose_rotation(socket: Transform3D, desired: Vector3, points: PackedVector3Array,
		clearance: RefCounted) -> Quaternion:
	var hand_basis := socket.basis.orthonormalized()
	for step: float in [0.0, .07, .14, .23, .36, .49, .65, .85, 1.08, 1.34, 1.57, 1.82, 2.1]:
		for axis: Vector3 in [Vector3.UP, Vector3.DOWN, Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
			var rotation := local_staff_rotation(hand_basis, desired.rotated(axis, step), 0.0)
			if staff_clearance(socket, rotation, points, clearance, .023):
				return rotation
			if step == 0.0:
				break
	var horizontal := Vector3(desired.x, 0, desired.z).normalized()
	for azimuth: float in [0.0, .26, -.26, .52, -.52, .78, -.78, 1.05, -1.05, 1.31, -1.31,
			1.57, -1.57, 1.83, -1.83, 2.09, -2.09, 2.36, -2.36, 2.62, -2.62, 2.88, -2.88, PI]:
		var heading := horizontal.rotated(Vector3.UP, azimuth)
		for pitch: float in [0.0, .05, -.05, .10, -.10, .17, -.17, .26, .36]:
			var shaft := heading * cos(pitch) + Vector3.UP * sin(pitch)
			for roll: float in [0.0, .44, -.44, .88, -.88, 1.57, -1.57, PI]:
				var rotation := local_staff_rotation(hand_basis, shaft, roll)
				if staff_clearance(socket, rotation, points, clearance, .010):
					return rotation
	return Quaternion(NAN, NAN, NAN, NAN)


func local_staff_rotation(hand_basis: Basis, shaft: Vector3, roll: float) -> Quaternion:
	var across := Vector3.BACK.slide(shaft).normalized()
	if across.is_zero_approx():
		across = Vector3.RIGHT
	across = across.rotated(shaft, roll)
	var local := hand_basis.inverse() * Basis(across, shaft, across.cross(shaft))
	return local.orthonormalized().get_rotation_quaternion()


func staff_clearance(socket: Transform3D, rotation: Quaternion, points: PackedVector3Array,
		clearance: RefCounted, margin: float) -> bool:
	var pose := Transform3D(socket.basis * Basis(rotation), socket.origin)
	for point: Vector3 in points:
		if (pose * point).y < .008:
			return false
	return not clearance.crosses_staff(pose, margin)

