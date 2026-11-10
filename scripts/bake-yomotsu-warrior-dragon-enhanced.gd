# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-field-enhanced.gd"

const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/yomotsu-warrior-dragon/"
const Profile := preload("res://Presentation/EnhancedCreatureProfile.gd")
const Components := preload("res://../scripts/bake-skeleton-enhanced.gd")
const WarriorClips := {12: "YomotsuOverheadWard", 15: "YomotsuClawRecoil", 23: "YomotsuCrouchedRise",
	26: "YomotsuKneelingWatch", 27: "YomotsuWideClawGuard", 28: "YomotsuRaisedClawAlert"}
const WarriorLengths := {12: 1.01, 15: .48, 23: 1.0, 26: 1.15, 27: .96, 28: .65}
const WarriorJoints := ["bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head",
	"bip01 l upperarm", "bip01 l forearm", "bip01 l hand", "bip01 r upperarm", "bip01 r forearm", "bip01 r hand",
	"bip01 l thigh", "bip01 l calf", "bip01 l foot", "bip01 r thigh", "bip01 r calf", "bip01 r foot"]
const DragonClips := {23: "DragonRedMantleOpen", 26: "DragonRedRaisedWingWatch",
	27: "DragonRedBankedWingRecoil", 28: "DragonRedWideWingAlert"}
const DragonLengths := {23: 1.18, 26: 1.15, 27: 1.01, 28: .61}
const DragonJoints := ["bip01", "bip01 spine1", "bip01 spine2", "bip01 spine3", "bip01 neck", "bip01 neck1",
	"bip01 neck2", "bip01 neck3", "bip01 head", "bip01 tail", "bip01 tail1", "bip01 tail2", "bip01 tail3",
	"box06", "box07", "box01", "box02"]
const WingChains := [["box06", "box07", "box08"], ["box01", "box02", "box03"]]


func run() -> void:
	bake_identity(245, WarriorClips, WarriorLengths, WarriorJoints, pose_warrior)
	bake_identity(59, DragonClips, DragonLengths, DragonJoints, pose_dragon)
	quit()


func bake_identity(body: int, clips: Dictionary, lengths: Dictionary, joints: Array, pose: Callable) -> void:
	var row := Registry.entry(body)
	for treatment: String in Profile.registered_assets(row):
		var source := Registry.asset_path(row, treatment)
		assert(FileAccess.get_sha256(source) == row.asset_sha256[treatment])
		var model := (load(source) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var skins: Array[Dictionary] = []
		var body_mesh := model.find_child("Body", true, false) as MeshInstance3D
		if body == 245:
			separate_warrior_blade(model, body_mesh, rig)
		skins.append(Ground.skin_points(body_mesh, rig))
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		for group: int in clips:
			var motion := fit_grounded(player, rig, skins, lengths[group], "bip01", joints, pose.bind(group), .008)
			assert(library.add_animation(clips[group], motion) == OK)
		verify_base_clips(player, source)
		player.stop()
		rig.reset_bone_poses()
		var scene := PackedScene.new()
		assert(scene.pack(model) == OK)
		assert(ResourceSaver.save(scene, Destination + "%d-%s.scn" % [body, treatment], ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("YOMOTSU WARRIOR AND DRAGON ", body, "/", treatment, ": ", clips.size(), " fitted motions with retained keys")


func separate_warrior_blade(model: Node3D, body: MeshInstance3D, rig: Skeleton3D) -> void:
	assert(body.mesh.get_surface_count() == 1 and body.mesh.get_blend_shape_count() == 0)
	var arrays := body.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var welded := PackedVector3Array()
	for point: Vector3 in vertices:
		welded.append(point.snapped(Vector3.ONE * .1))
	var groups := Components.split_components(welded, indices)
	var hand := rig.find_bone("bip01 r hand")
	var blade_vertices := {}
	for group: Array in groups:
		if matches_blade(group, arrays, body.skin, rig, hand):
			assert(blade_vertices.is_empty(), "Only the atlas-isolated right-hand blade should match")
			for vertex: int in group:
				blade_vertices[vertex] = true
	assert(not blade_vertices.is_empty())
	var blade_faces := PackedInt32Array()
	var body_faces := PackedInt32Array()
	for index in range(0, indices.size(), 3):
		var face := indices.slice(index, index + 3)
		var is_blade := blade_vertices.has(face[0])
		assert(blade_vertices.has(face[1]) == is_blade and blade_vertices.has(face[2]) == is_blade)
		if is_blade:
			blade_faces.append_array(face)
		else:
			body_faces.append_array(face)
	assert(blade_faces.size() + body_faces.size() == indices.size())
	assert(blade_faces.size() / 3 in [38, 608], "Unexpected source sword triangle count")
	var material := body.mesh.surface_get_material(0)
	var flags: int = body.mesh.surface_get_format(0) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
	var blade := MeshInstance3D.new()
	blade.name = "YomotsuBlade"
	blade.transform = body.transform
	blade.skin = body.skin
	blade.skeleton = body.skeleton
	blade.mesh = mesh_part(arrays, blade_faces, material, flags)
	body.get_parent().add_child(blade)
	blade.owner = model
	body.mesh = mesh_part(arrays, body_faces, material, flags)
	print("YOMOTSU BLADE PARTITION: ", blade_faces.size() / 3, " blade and ", body_faces.size() / 3, " retained body triangles")


func matches_blade(group: Array, arrays: Array, skin: Skin, rig: Skeleton3D, hand: int) -> bool:
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var stride := weights.size() / uv.size()
	for vertex: int in group:
		if uv[vertex].x > .19:
			return false
		var hand_weight := 0.0
		for slot in stride:
			var i := vertex * stride + slot
			if weights[i] <= 0.0:
				continue
			var bone := skin.get_bind_bone(joints[i])
			if bone < 0:
				bone = rig.find_bone(skin.get_bind_name(joints[i]))
			if bone == hand:
				hand_weight += weights[i]
		if hand_weight < .999:
			return false
	return group.size() >= 100


func mesh_part(source: Array, indices: PackedInt32Array, material: Material, flags: int) -> ArrayMesh:
	var used := PackedInt32Array()
	var new_indices := PackedInt32Array()
	var remap := {}
	for index in indices:
		if not remap.has(index):
			remap[index] = used.size()
			used.append(index)
		new_indices.append(remap[index])
	var arrays := source.duplicate()
	var vertex_count: int = source[Mesh.ARRAY_VERTEX].size()
	for channel in Mesh.ARRAY_INDEX:
		if source[channel] == null:
			continue
		var original: Variant = source[channel]
		var part: Variant = original.duplicate()
		part.resize(0)
		var stride: int = original.size() / vertex_count
		assert(stride > 0 and original.size() == vertex_count * stride)
		for vertex in used:
			for offset in stride:
				part.append(original[vertex * stride + offset])
		arrays[channel] = part
	arrays[Mesh.ARRAY_INDEX] = new_indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	mesh.surface_set_material(0, material)
	return mesh


func envelope(phase: float, start: float, peak: float, hold: float, end: float) -> float:
	return smoothstep(start, peak, phase) * (1.0 - smoothstep(hold, end, phase))


func pose_warrior(rig: Skeleton3D, phase: float, group: int) -> void:
	var crouch := 0.0
	var guard := 0.0
	var reach := 0.0
	var ward := 0.0
	var spread := 0.0
	match group:
		12:
			guard = .65 * envelope(phase, .02, .28, .38, .61)
			ward = envelope(phase, .30, .58, .77, 1.0)
			crouch = .26 * (guard + ward)
		15:
			guard = 1.0 - .90 * smoothstep(.66, 1.0, phase)
			crouch = .45 * guard
		23:
			crouch = 1.0 - smoothstep(.18, .80, phase)
		26:
			crouch = .60 * envelope(phase, .04, .24, .73, .96)
			guard = .41 * crouch
		27:
			reach = envelope(phase, .02, .26, .76, .99)
			spread = .35 + .61 * reach
			crouch = .23 * reach
		28:
			reach = smoothstep(.10, .58, phase)
			spread = .28 + .62 * reach
			guard = .45 * reach
	var inverse := rig.global_basis.inverse()
	var ankles := {}
	var hands := {}
	for side: String in ["l", "r"]:
		var sign_side := 1.0 if side == "l" else -1.0
		var ankle := rig.get_bone_global_pose(rig.find_bone("bip01 %s foot" % side))
		var shift := Vector3(.16 * sign_side * (spread + .4 * crouch), .18 * reach if side == "r" else 0.0, .06 * crouch)
		ankle.origin += inverse * shift
		ankles[side] = ankle
		hands[side] = joint_world(rig, "bip01 %s hand" % side)
	var hips := rig.find_bone("bip01")
	var placement := rig.get_bone_global_pose(hips)
	placement.origin += inverse * Vector3(-.10 * reach, -.56 * crouch - .08 * spread, -.12 * crouch)
	rig.set_bone_global_pose(hips, placement)
	rig.force_update_all_bone_transforms()
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .47 * crouch)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .43 * crouch - .19 * ward)
	turn_world(rig, "bip01 spine2", Vector3.UP, .32 * reach - .15 * guard)
	turn_world(rig, "bip01 head", Vector3.RIGHT, .21 * crouch - .23 * ward)
	var chest := joint_world(rig, "bip01 spine2")
	for side: String in ["l", "r"]:
		var sign_side := 1.0 if side == "l" else -1.0
		fit_foot(rig, side, ankles[side])
		var hand: Vector3 = hands[side]
		hand = hand.lerp(chest + Vector3(.42 * sign_side, -.57, .48), crouch)
		hand = hand.lerp(chest + Vector3(.37 * sign_side, .44, .79), guard)
		hand = hand.lerp(chest + Vector3(.52 * sign_side, 1.03, .35), ward)
		var claw := Vector3(.83 * sign_side, .32, .72 if side == "r" else -.40)
		hand = hand.lerp(chest + claw, spread)
		fit_arm(rig, side, hand)
		turn_world(rig, "bip01 %s hand" % side, Vector3.BACK, .36 * sign_side * (guard + ward + .4 * spread))


func pose_dragon(rig: Skeleton3D, phase: float, group: int) -> void:
	var fold := 0.0
	var open := 0.0
	var rise := 0.0
	var bank := 0.0
	var alert := 0.0
	match group:
		23:
			open = envelope(phase, .10, .43, .66, .95)
			fold = 1.0 - open
			rise = .43 * open
		26:
			rise = envelope(phase, .04, .31, .79, .99)
			fold = 1.0 - rise
			open = .78 * rise
			alert = .18 * sin(TAU * phase) * rise
		27:
			open = .81 + .17 * sin(TAU * phase)
			rise = .55 + .33 * cos(TAU * phase)
			bank = .36 * sin(TAU * phase) + .21
		28:
			open = .35 + .64 * smoothstep(.04, .46, phase)
			rise = .59 * smoothstep(.08, .59, phase)
			alert = smoothstep(.07, .47, phase)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .13 * fold + .12 * alert)
	turn_world(rig, "bip01 spine2", Vector3.BACK, -.12 * bank)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, .19 * fold - .21 * rise)
	turn_world(rig, "bip01 neck1", Vector3.RIGHT, .08 * alert - .15 * rise)
	turn_world(rig, "bip01 neck2", Vector3.UP, .24 * bank)
	turn_world(rig, "bip01 head", Vector3.UP, .24 * alert + .17 * bank)
	turn_world(rig, "bip01 tail", Vector3.RIGHT, -.29 * open + .21 * fold)
	turn_world(rig, "bip01 tail1", Vector3.UP, .23 * bank)
	turn_world(rig, "bip01 tail2", Vector3.RIGHT, -.26 * alert - .21 * rise)
	turn_world(rig, "bip01 tail3", Vector3.UP, -.28 * bank)
	for index in WingChains.size():
		var side := 1.0 if index == 0 else -1.0
		var chain: Array = WingChains[index]
		var height := maxf(.16, rise + .68 * bank * side)
		for segment in 2:
			var folded := Vector3(side * (.42 + .16 * segment), .38 - .18 * segment, -.83)
			var wide := Vector3(side * (1.0 - .22 * segment), height * (.64 + .56 * segment), -.19 + .11 * segment)
			var amount := clampf(fold + open, 0.0, 1.0)
			var direction := folded.normalized().slerp(wide.normalized(), open / maxf(.01, fold + open))
			point_link(rig, chain[segment], chain[segment + 1], direction, amount)


func point_link(rig: Skeleton3D, label: String, child_label: String, direction: Vector3, amount: float) -> void:
	var joint := rig.find_bone(label)
	var child := rig.find_bone(child_label)
	var pose := rig.get_bone_global_pose(joint)
	var along := (rig.get_bone_global_pose(child).origin - pose.origin).normalized()
	var target := (rig.global_basis.inverse() * direction).normalized()
	pose.basis = Basis(Quaternion.IDENTITY.slerp(Quaternion(along, target), amount)) * pose.basis
	rig.set_bone_global_pose(joint, pose)
	rig.force_update_all_bone_transforms()
