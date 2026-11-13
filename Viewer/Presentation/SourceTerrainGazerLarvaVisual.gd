# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/GazerLarvaActionsVisual.gd"

const Ground := preload("res://Presentation/SourceGroundLookup.gd")

var terrain := preload("res://Presentation/SourceFlyingCreatureTerrain.gd").new()
var beginning_fall := false


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(1.35, 2.20))
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	var combined := terrain.skin.duplicate(true)
	for index in range(1, meshes.size()):
		var mesh := meshes[index] as MeshInstance3D
		if mesh.skin == null:
			continue
		var part := Ground.skin_points(mesh, skeleton)
		var offset: int = combined.bones.size()
		combined.bones.append_array(part.bones)
		combined.bind_poses.append_array(part.bind_poses)
		for original: Dictionary in part.surfaces:
			var surface := original.duplicate()
			var bindings: PackedInt32Array = original.bindings.duplicate()
			for slot in bindings.size():
				bindings[slot] += offset
			surface.bindings = bindings
			combined.surfaces.append(surface)
	terrain.skin = combined
	animator.mixer_applied.connect(settle_death)


func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if dead:
		terrain.sample()
	return true


func begin_death_from(source: Node3D) -> float:
	global_transform = source.global_transform
	model.transform = source.model.transform
	model.position -= source.terrain.shift
	terrain.sample()
	beginning_fall = true
	var duration := super.begin_death_from(source)
	beginning_fall = false
	settle_death()
	return duration


func settle_death() -> void:
	if dead and not beginning_fall and animator.assigned_animation == "Death" 			and animator.current_animation_position > 0.0:
		terrain.settle(self)


func corpse_snapshot_floor() -> float:
	return terrain.snapshot_floor(self)
