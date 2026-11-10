# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/FireActionsVisual.gd"

const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Fitted := ["FireKindleAndRise", "FireCrownAlert"]
var fitted_fall := preload("res://Presentation/DisplayedCreatureFallPlayback.gd").new()
var flame_skin := {"bones": PackedInt32Array(), "bind_poses": [], "surfaces": []}

func _ready() -> void:
	super._ready()
	for mesh: MeshInstance3D in meshes:
		if mesh.skin == null:
			continue
		var skin := Ground.skin_points(mesh, skeleton)
		var offset: int = flame_skin.bones.size()
		flame_skin.bones.append_array(skin.bones)
		flame_skin.bind_poses.append_array(skin.bind_poses)
		for surface: Dictionary in skin.surfaces:
			var local := surface.duplicate()
			var bindings: PackedInt32Array = surface.bindings.duplicate()
			for index in bindings.size():
				bindings[index] += offset
			local.bindings = bindings
			flame_skin.surfaces.append(local)
	assert(not flame_skin.surfaces.is_empty())
	animator.mixer_applied.connect(settle_fall)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if dead or current_clip not in Fitted:
		return
	var support := fitted_fall.floor_under(self)
	skeleton.force_update_all_bone_transforms()
	var gap := Ground.minimum_plane_gap(flame_skin, skeleton, skeleton.global_transform, support.position, support.normal)
	if gap < .002:
		model.global_position.y += (.002 - gap) / float(support.normal.y)
		update_fire_pose()

func settle_fall() -> void:
	if fitted_fall.plane.is_empty():
		return
	fitted_fall.settle(self)
	update_fire_pose()

func begin_death_from(source: Node3D) -> float:
	if source.current_clip not in Fitted:
		play("Death", .08)
		return animator.get_animation("Death").length
	global_transform = source.global_transform
	fitted_fall.skin = flame_skin
	var duration := fitted_fall.begin_from_display(self, source, source.fitted_fall, source.current_clip, false)
	fitted_fall.blend_length = minf(.20, duration)
	for bone in source.skeleton.get_bone_count():
		fitted_fall.blend_pose.append(source.skeleton.get_bone_pose(bone))
	settle_fall()
	return duration

func corpse_snapshot_floor() -> float:
	return NAN if fitted_fall.plane.is_empty() else fitted_fall.snapshot_floor(self)
