# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/BoneKnightActionsVisual.gd"

const DisplayedPose := preload("res://Presentation/CreatureFallPlayback.gd")
var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(1.9, 2.0))
	terrain.skin = {"bones": PackedInt32Array(), "bind_poses": [], "surfaces": []}
	for part: Dictionary in gesture_skins:
		var offset: int = terrain.skin.bones.size()
		terrain.skin.bones.append_array(part.bones)
		terrain.skin.bind_poses.append_array(part.bind_poses)
		for original: Dictionary in part.surfaces:
			var surface := original.duplicate()
			var bindings: PackedInt32Array = original.bindings.duplicate()
			for index in bindings.size():
				bindings[index] += offset
			surface.bindings = bindings
			terrain.skin.surfaces.append(surface)
	animator.mixer_applied.connect(settle_fall)


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	super._physics_process(delta)
	if not contact.enabled:
		clear_gesture_ground()


func clear_gesture_ground() -> void:
	terrain.release_live()
	super.clear_gesture_ground()
	terrain.settle_live(.0005)


func receive_action(request: Dictionary) -> bool:
	terrain.release_live()
	if not super.receive_action(request):
		return false
	if dead:
		terrain.prepare_collapse()
	return true


func settle_fall() -> void:
	if dead:
		terrain.settle(self)


func begin_death_from(source: Node3D) -> float:
	var previous: RefCounted = source.terrain
	terrain.split = previous.split
	if not source.dead:
		model.transform = source.model.transform
		previous = DisplayedPose.new()
		previous.plane = source.terrain.plane
	return terrain.begin_from_source(self, source, previous, false)


func corpse_snapshot_floor() -> float:
	return terrain.snapshot_floor(self)
