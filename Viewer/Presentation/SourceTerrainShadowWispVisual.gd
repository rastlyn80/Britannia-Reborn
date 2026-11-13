# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedShadowWispVisual.gd"

var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()
var copying_pose := false


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(.65, .65))
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	for index in range(1, meshes.size()):
		var part := Ground.skin_points(meshes[index], skeleton)
		assert(part.bones == terrain.skin.bones and part.bind_poses == terrain.skin.bind_poses)
		terrain.skin.surfaces.append_array(part.surfaces)
	# The terrain helper owns the skeletal blend as well as the support plane.
	animator.mixer_applied.disconnect(blend_death_pose)


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	super._physics_process(delta)


func update_energy_pose() -> void:
	if terrain.actor != null and not copying_pose:
		if dead:
			if not terrain.plane.is_empty() and animator.current_animation_position > 0.0:
				terrain.settle(self)
		else:
			terrain.settle_live(.0005)
	super.update_energy_pose()


func receive_action(request: Dictionary) -> bool:
	if not dead:
		terrain.release_live()
	if not super.receive_action(request):
		return false
	if dead:
		terrain.prepare_collapse()
	return true


func begin_death_from(source: Node3D) -> float:
	global_transform = source.global_transform
	model.transform = source.model.transform
	terrain.split = source.terrain.split
	var previous: RefCounted = source.terrain
	if not source.dead:
		previous = preload("res://Presentation/CreatureFallPlayback.gd").new()
		previous.plane = source.terrain.plane
	copying_pose = true
	var duration := terrain.begin_from_display(self, source, previous, source.animator.assigned_animation, false)
	copying_pose = false
	if not source.dead:
		terrain.blend_length = minf(.12, duration)
		for bone in source.skeleton.get_bone_count():
			terrain.blend_pose.append(source.skeleton.get_bone_pose(bone))
			skeleton.set_bone_pose(bone, terrain.blend_pose[bone])
		skeleton.force_update_all_bone_transforms()
	super.update_energy_pose()
	return duration


func corpse_snapshot_floor() -> float:
	return terrain.snapshot_floor(self)
