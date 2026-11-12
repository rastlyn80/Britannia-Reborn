# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/RabbitActionsVisual.gd"

const Terrain := preload("res://Presentation/SourceFlyingCreatureTerrain.gd")
const Fall := preload("res://Presentation/SourceZombieGraveFall.gd")
const Displayed := preload("res://Presentation/SourceRenderedPose.gd")
var terrain := Terrain.new()
var fall := Fall.new()
var displayed := Displayed.new()
var displayed_space := Transform3D.IDENTITY
var starting_fall := false


func _ready() -> void:
	super._ready()
	terrain.actor = self
	terrain.extent = Vector2(.29, .59)
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.skin != null and mesh.is_visible_in_tree():
			add_skin(Ground.skin_points(mesh, skeleton))
	assert(contact.stride == 8 and contact.feet.size() == 4 and not terrain.skin.is_empty())
	fall.skin = terrain.skin
	animator.mixer_applied.connect(release_support)
	contact.modification_processed.connect(settle_live)


func add_skin(part: Dictionary) -> void:
	if terrain.skin.is_empty():
		terrain.skin = part.duplicate(true)
		return
	var bones: PackedInt32Array = terrain.skin.bones.duplicate()
	var offset := bones.size()
	bones.append_array(part.bones)
	terrain.skin.bones = bones
	terrain.skin.bind_poses.append_array(part.bind_poses)
	for original: Dictionary in part.surfaces:
		var surface := original.duplicate()
		var bindings: PackedInt32Array = surface.bindings.duplicate()
		for index in bindings.size():
			bindings[index] += offset
		surface.bindings = bindings
		terrain.skin.surfaces.append(surface)


func _physics_process(_delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	var normal: Vector3 = terrain.plane.get("normal", Vector3.UP)
	var slope := Basis(Quaternion(Vector3.UP, (global_basis.inverse() * normal).normalized()))
	model.basis = (slope * source_model_basis).scaled_local(model.scale)
	contact.sample(get_world_3d().direct_space_state, global_position)
	var tunnel := skeleton.get_node_or_null("NativeTunnelPose") as SkeletonModifier3D
	if tunnel != null and not tunnel.modification_processed.is_connected(capture_display):
		tunnel.modification_processed.connect(capture_display)


func release_support() -> void:
	if not dead:
		terrain.release_live()


func settle_live() -> void:
	if dead:
		return
	if not skeleton.has_node("NativeTunnelPose"):
		terrain.settle_live()
	capture_display()


func capture_display() -> void:
	if not dead:
		displayed.capture(skeleton)
		displayed_space = global_transform.affine_inverse() * skeleton.global_transform


func play_gait(moving: bool, speed: float) -> void:
	if moving:
		var idle := current_clip in ["Fidget", "RabbitEarCheck", "RabbitLookAround"]
		if current_clip == "RabbitQuietCrouch":
			var request: Dictionary = get_meta("native_action", {})
			idle = request.get("protocol") == "new" and request.get("type") == 5
		if idle:
			action_remaining = 0.0
	super.play_gait(moving, speed)


func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if dead:
		fall.split = terrain.split
		fall.remember_floor(self, terrain.plane if not terrain.plane.is_empty() else support_plane())
		terrain.live_lift = 0.0
	return true


func begin_death_from(source: Node3D) -> float:
	global_transform = source.global_transform
	model.global_transform = source.model.global_transform
	dead = true
	contact.enabled = false
	var previous: RefCounted = source.fall if source.dead else source.terrain
	fall.split = previous.split
	starting_fall = true
	var duration := fall.begin_from_display(self, source, previous, source.animator.assigned_animation, false)
	starting_fall = false
	if not source.dead:
		fall.blend_length = minf(.19, duration)
		var source_rig: Skeleton3D = source.skeleton
		var last = source.displayed
		var recorded: bool = last.rig_id == source_rig.get_instance_id() and Engine.get_process_frames() - last.frame <= 1
		var source_space: Transform3D = source.global_transform * source.displayed_space if recorded else source_rig.global_transform
		var into_fall := skeleton.global_transform.affine_inverse() * source_space
		for bone in source_rig.get_bone_count():
			var pose: Transform3D = last.poses[bone] if recorded else source_rig.get_bone_pose(bone)
			if source_rig.get_bone_parent(bone) < 0:
				pose = into_fall * pose
			fall.blend_pose.append(pose)
			skeleton.set_bone_pose(bone, pose)
		if source_rig.has_node("NativeTunnelPose"):
			skeleton.force_update_all_bone_transforms()
			var gap := fall.step_gap(skeleton) if fall.split else Ground.minimum_plane_gap(
				fall.skin, skeleton, skeleton.global_transform, fall.plane.position, fall.plane.normal)
			fall.initial_depth = maxf(0.0, .002 - gap)
	fall.settle(self)
	return duration


func settle_collapse() -> void:
	if not starting_fall and not fall.plane.is_empty():
		fall.settle(self)


func corpse_snapshot_floor() -> float:
	return fall.snapshot_floor(self) if not fall.plane.is_empty() else super.corpse_snapshot_floor()
