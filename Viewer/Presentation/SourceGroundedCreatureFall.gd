# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/CougarTerrainFall.gd"

var setting_up := false


func enter(actor: Node3D, source: Node3D) -> float:
	var continuing: bool = source.dead and source.current_clip in FALLS
	var source_rig: Skeleton3D = source.skeleton
	var sampled = source.contact.displayed
	var recorded: bool = not continuing and sampled.rig_id == source_rig.get_instance_id() \
		and sampled.poses.size() == source_rig.get_bone_count() and Engine.get_process_frames() - sampled.frame <= 1
	var displayed_space: Transform3D = source.skeleton.global_transform
	if recorded:
		displayed_space = source.global_transform * source.contact.displayed_space
		blend_pose.assign(sampled.poses)
	else:
		for bone in source_rig.get_bone_count():
			blend_pose.append(source_rig.get_bone_pose(bone))
	var support: Dictionary = source.contact.ground
	split = source.contact.use_local_planes
	if source.contact.death.plane.has("collider"):
		support = source.contact.death.plane
		split = source.contact.death.split
	elif support.is_empty() or not support.has("collider"):
		support = floor_under(source)
		split = source.contact.spans_treads(support)
	remember_floor(actor, support)
	skin = supported_skin(actor)
	actor.global_transform = source.global_transform
	actor.model.global_transform = source.model.global_transform
	actor.current_clip = source.current_clip if continuing else "Death"
	var time: float = source.animator.current_animation_position if continuing else 0.0
	var speed: float = absf(source.animator.get_playing_speed()) if continuing else 1.0
	if is_zero_approx(speed):
		speed = 1.0
	var player: AnimationPlayer = actor.animator
	setting_up = true
	player.speed_scale = 1.0
	player.play(actor.current_clip, 0.0, speed)
	player.advance(0.0)
	player.seek(time, true)
	setting_up = false
	var rig: Skeleton3D = actor.skeleton
	var root := rig.find_bone("__root")
	assert(root >= 0 and rig.get_bone_parent(root) < 0)
	blend_pose[root] = rig.global_transform.affine_inverse() * displayed_space * blend_pose[root]
	blend_start = time
	blend_length = minf((.08 if continuing else .15) * speed, player.current_animation_length - time)
	if blend_length <= 0.0:
		blend_pose.clear()
	actor.action_remaining = maxf(0.0, player.current_animation_length - time) / speed
	settle(actor)
	return actor.action_remaining


func settle(actor: Node3D) -> void:
	if not setting_up:
		super.settle(actor)


func supported_skin(actor: Node3D) -> Dictionary:
	var combined := {"bones": PackedInt32Array(), "bind_poses": [], "surfaces": []}
	for mesh: MeshInstance3D in actor.contact.surfaces:
		if not mesh.is_visible_in_tree():
			continue
		var part: Dictionary = actor.contact.surfaces[mesh]
		var offset: int = combined.bones.size()
		combined.bones.append_array(part.bones)
		combined.bind_poses.append_array(part.bind_poses)
		for surface: Dictionary in part.surfaces:
			var copy := surface.duplicate()
			var bindings: PackedInt32Array = surface.bindings.duplicate()
			for index in bindings.size():
				bindings[index] += offset
			copy.bindings = bindings
			combined.surfaces.append(copy)
	return combined
