# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-field-enhanced.gd"

const DonorScene := "res://local-art/creatures/enhanced-creature-actions/215-modern.scn"
const RatScene := "res://Art/Creatures/Rat/rat-deaths.scn"
const Clips := {
	"GiantRatForwardBite": "RatForwardBite",
	"GiantRatNoseRecoil": "RatNoseRecoil",
	"GiantRatTailUnfurl": "RatTailUnfurl",
	"GiantRatForage": "RatForage",
	"GiantRatScentCheck": "RatScentCheck",
	"GiantRatTailSweep": "RatTailSweep",
	"GiantRatNoseAlert": "RatNoseAlert",
}
# The small rat has shorter limb chains and two tail joints. These entries
# identify the donor segment endpoints and the share of each turn to carry.
const Segments := {
	"base": ["bip01", "__root", .85],
	"spine": ["bip01 spine1", "bip01", .82],
	"neck": ["bip01 neck", "bip01 spine1", .86],
	"head": ["bip01 head", "bip01 neck", .95],
	"mouth": ["bip01 ponytail1", "bip01 head", .72],
	"tailbone": ["bip01 tail1", "bip01 spine", .54],
	"tail": ["bip01 tail3", "bip01 tail1", .60],
	"base.001_L": ["bip01 l upperarm", "bip01 l clavicle", .60],
	"base.001_L.001": ["bip01 l forearm", "bip01 l upperarm", .60],
	"base.001_R": ["bip01 r upperarm", "bip01 r clavicle", .60],
	"base.001_R.001": ["bip01 r forearm", "bip01 r upperarm", .60],
	"base_L": ["bip01 l thigh", "bip01 spine", .58],
	"base_L.001": ["bip01 l calf", "bip01 l thigh", .58],
	"base_R": ["bip01 r thigh", "bip01 spine", .58],
	"base_R.001": ["bip01 r calf", "bip01 r thigh", .58],
}

var donor: Skeleton3D
var donor_player: AnimationPlayer
var donor_idle: Array[Transform3D]
var links: Array[Dictionary]
var reach_ratio := 0.0


func run() -> void:
	var folder: String = get_script().resource_path.get_base_dir()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--study="):
			folder = argument.trim_prefix("--study=")
	var donor_model := (load(DonorScene) as PackedScene).instantiate()
	var model := (load(RatScene) as PackedScene).instantiate()
	root.add_child(donor_model)
	root.add_child(model)
	donor = donor_model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	donor_player = donor_model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	donor_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	donor_player.play("Idle", 0.0)
	donor_player.advance(0.0)
	donor_player.seek(0.0, true)
	donor.force_update_all_bone_transforms()
	for joint in donor.get_bone_count():
		donor_idle.append(donor.get_bone_global_pose(joint))
	configure_links(rig)
	var source_reach := world_bone(donor, "bip01").distance_to(world_bone(donor, "bip01 head"))
	var target_reach := world_bone(rig, "base").distance_to(world_bone(rig, "head"))
	reach_ratio = target_reach / source_reach
	assert(reach_ratio > .15 and reach_ratio < .40)
	var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
	player.remove_animation_library("")
	player.add_animation_library("", library)
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var ears := seat_ears(mesh)
	var skins: Array[Dictionary] = [Ground.skin_points(mesh, rig)]
	var records := {}
	for label: String in Clips:
		donor_player.play(label, 0.0)
		donor_player.advance(0.0)
		var duration := donor_player.current_animation_length
		var fitted := fit_grounded(player, rig, skins, duration, "root", Segments.keys(), pose_from_donor.bind(duration), .0025)
		var name: String = Clips[label]
		assert(library.add_animation(name, fitted) == OK)
		records[name] = measure(player, rig, skins[0], name)
	verify_base_clips(player, RatScene)
	player.stop()
	rig.reset_bone_poses()
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	var packed := PackedScene.new()
	var scene := folder.path_join("rat-enhanced.scn")
	assert(packed.pack(model) == OK and ResourceSaver.save(packed, scene, ResourceSaver.FLAG_COMPRESS) == OK)
	var output := FileAccess.open(folder.path_join("rat-enhanced-bake.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"source_sha256": FileAccess.get_sha256(RatScene),
		"donor_sha256": FileAccess.get_sha256(DonorScene), "scene_sha256": FileAccess.get_sha256(scene),
		"body": 238, "animation_body": 215, "reach_ratio": reach_ratio, "clips": records,
		"ear_vertices": ears}, "  "))
	output.close()
	donor_model.free()
	model.free()
	print("ORDINARY RAT FIT: ", records.size(), " source-linked clips; ", records.size() * 81, " sampled target poses")
	quit()


func seat_ears(node: MeshInstance3D) -> int:
	var source := node.mesh as ArrayMesh
	assert(source.get_surface_count() == 1 and source.get_blend_shape_count() == 0)
	var arrays := source.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var stride := bones.size() / vertices.size()
	var unique := {}
	var moved := 0
	# Both disconnected ear islands are rigidly weighted to the head. Their
	# measured gaps are about 10 mm before this symmetric placement correction.
	for index in vertices.size():
		var point := vertices[index]
		if not (absf(point.x) > .023 and absf(point.x) < .048 and point.y > .1165
				and point.z > .1097 and point.z < .1120):
			continue
		for influence in stride:
			var slot := index * stride + influence
			assert(weights[slot] < .00001 or node.skin.get_bind_name(bones[slot]) == &"head")
		unique[point.snapped(Vector3.ONE * .00001)] = true
		vertices[index] += Vector3(-signf(point.x) * .0095, -.0105, .0026)
		moved += 1
	assert(unique.size() == 244)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var corrected := ArrayMesh.new()
	corrected.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	corrected.surface_set_material(0, source.surface_get_material(0))
	node.mesh = corrected
	return moved


func configure_links(rig: Skeleton3D) -> void:
	for name: String in Segments:
		var source: Array = Segments[name]
		var target_joint := rig.find_bone(name)
		var source_joint := donor.find_bone(source[0])
		var source_parent := donor.find_bone(source[1])
		assert(target_joint >= 0 and source_joint >= 0 and source_parent >= 0, name)
		var source_reference := donor_idle[source_parent]
		var source_relative := source_reference.affine_inverse() * donor_idle[source_joint]
		var source_frame := (donor.global_basis * source_reference.basis).orthonormalized().get_rotation_quaternion()
		var target_parent := rig.get_bone_parent(target_joint)
		var target_frame := (rig.global_basis * rig.get_bone_global_rest(target_parent).basis).orthonormalized().get_rotation_quaternion()
		var alignment := target_frame.inverse() * source_frame
		links.append({"joint": target_joint, "source": source_joint, "parent": source_parent,
			"rest_rotation": source_relative.basis.get_rotation_quaternion(),
			"alignment": alignment, "strength": source[2]})


func pose_from_donor(rig: Skeleton3D, phase: float, duration: float) -> void:
	donor_player.seek(duration * phase, true)
	donor.force_update_all_bone_transforms()
	for link: Dictionary in links:
		var relative := donor.get_bone_global_pose(link.parent).affine_inverse() * donor.get_bone_global_pose(link.source)
		var source_delta := relative.basis.get_rotation_quaternion() * (link.rest_rotation as Quaternion).inverse()
		var alignment: Quaternion = link.alignment
		var target_delta := (alignment * source_delta * alignment.inverse()).normalized()
		var fitted := Quaternion.IDENTITY.slerp(target_delta, link.strength)
		rig.set_bone_pose_rotation(link.joint, (fitted * rig.get_bone_pose_rotation(link.joint)).normalized())
	var donor_hip := donor.find_bone("bip01")
	var travel := donor.global_basis * (donor.get_bone_global_pose(donor_hip).origin - donor_idle[donor_hip].origin)
	var target_root := rig.find_bone("root")
	var pose := rig.get_bone_global_pose(target_root)
	pose.origin += rig.global_basis.inverse() * (travel.slide(Vector3.UP) * reach_ratio)
	rig.set_bone_global_pose(target_root, pose)
	rig.force_update_all_bone_transforms()


func measure(player: AnimationPlayer, rig: Skeleton3D, skin: Dictionary, name: String) -> Dictionary:
	player.play(name, 0.0)
	player.advance(0.0)
	var min_floor := INF
	var min_head := INF
	var max_head := -INF
	var reach := 0.0
	var first := Vector3.ZERO
	for sample in 81:
		player.seek(player.current_animation_length * (sample + .25) / 81.0, true)
		rig.force_update_all_bone_transforms()
		var point := world_bone(rig, "head")
		assert(point.is_finite())
		var tail := world_bone(rig, "tail")
		if sample == 0:
			first = tail
		reach = maxf(reach, tail.distance_to(first))
		min_head = minf(min_head, point.y)
		max_head = maxf(max_head, point.y)
		min_floor = minf(min_floor, Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
	assert(min_floor > .001 and max_head < .28, "%s floor %f / head %f" % [name, min_floor, max_head])
	return {"duration": player.current_animation_length, "min_floor": min_floor,
		"head_height": [min_head, max_head], "tail_excursion": reach}


func world_bone(rig: Skeleton3D, label: String) -> Vector3:
	return rig.to_global(rig.get_bone_global_pose(rig.find_bone(label)).origin)
