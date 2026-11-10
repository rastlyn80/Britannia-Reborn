# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/AirActionsVisual.gd"

const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Fitted := ["AirVortexFormation", "AirSpreadAlert"]
var fitted_fall := preload("res://Presentation/DisplayedCreatureFallPlayback.gd").new()
var body_skin := {}

func _ready() -> void:
	super._ready()
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.skin != null:
			body_skin = Ground.skin_points(mesh, skeleton)
			break
	assert(not body_skin.is_empty())
	animator.mixer_applied.connect(fitted_fall.settle.bind(self))

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if dead or current_clip not in Fitted:
		return
	var support := fitted_fall.floor_under(self)
	skeleton.force_update_all_bone_transforms()
	var gap := Ground.minimum_plane_gap(body_skin, skeleton, skeleton.global_transform, support.position, support.normal)
	if gap < .002:
		model.global_position += Vector3.UP * (.002 - gap) / float(support.normal.y)
		update_wind_pose()

func begin_death_from(source: Node3D) -> float:
	if source.current_clip not in Fitted:
		play("Death", .08)
		return animator.get_animation("Death").length
	global_transform = source.global_transform
	fitted_fall.skin = body_skin
	var duration := fitted_fall.begin_from_display(self, source, source.fitted_fall, source.current_clip, false)
	fitted_fall.blend_length = minf(.20, duration)
	for bone in source.skeleton.get_bone_count():
		fitted_fall.blend_pose.append(source.skeleton.get_bone_pose(bone))
	fitted_fall.settle(self)
	return duration

func corpse_snapshot_floor() -> float:
	return INF if fitted_fall.plane.is_empty() else fitted_fall.snapshot_floor(self)
