# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedCyclopsVisual.gd"

const DisplayedPose := preload("res://Presentation/CreatureFallPlayback.gd")
var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(2.75, 2.5))
	terrain.skin = body_skin.duplicate(true)
	var offset: int = terrain.skin.bones.size()
	terrain.skin.bones.append_array(mallet_skin.bones)
	terrain.skin.bind_poses.append_array(mallet_skin.bind_poses)
	for original: Dictionary in mallet_skin.surfaces:
		var surface := original.duplicate()
		var bindings: PackedInt32Array = original.bindings.duplicate()
		for index in bindings.size():
			bindings[index] += offset
		surface.bindings = bindings
		terrain.skin.surfaces.append(surface)
	contact.modification_processed.connect(settle_living)


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	restore_gesture()
	terrain.sample()
	super._physics_process(delta)
	if not contact.enabled:
		settle()


func settle() -> void:
	if terrain.actor == null:
		super.settle()
	elif dead:
		terrain.settle(self)
	else:
		terrain.release_live()
		super.settle()
		settle_living()


func settle_living() -> void:
	terrain.settle_live(.0005)


func raise_over_steps(_plane: Dictionary) -> void:
	# The combined terrain pass already measures the body and mallet together.
	pass


func receive_action(request: Dictionary) -> bool:
	terrain.release_live()
	if not super.receive_action(request):
		return false
	if dead:
		fall.plane = {}
		terrain.prepare_collapse()
	return true


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
