# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedMatriarchVisual.gd"

const DisplayedPose := preload("res://Presentation/CreatureFallPlayback.gd")
var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()
var unarmed_skin: Dictionary
var armed_skin: Dictionary


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(2.7, 2.5))
	unarmed_skin = terrain.skin
	armed_skin = unarmed_skin.duplicate(true)
	var offset: int = armed_skin.bones.size()
	armed_skin.bones.append_array(sceptre_skin.bones)
	armed_skin.bind_poses.append_array(sceptre_skin.bind_poses)
	for original: Dictionary in sceptre_skin.surfaces:
		var surface := original.duplicate()
		var bindings: PackedInt32Array = original.bindings.duplicate()
		for index in bindings.size():
			bindings[index] += offset
		surface.bindings = bindings
		armed_skin.surfaces.append(surface)
	contact.modification_processed.connect(settle)


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	restore_gesture()
	terrain.sample()
	super._physics_process(delta)
	if current_clip in entry.grounded_gestures or not contact.enabled:
		settle()


func settle() -> void:
	if terrain.actor == null:
		super.settle()
		return
	if dead:
		if held_in_fall:
			model.position -= terrain.shift
			terrain.shift = Vector3.ZERO
			super.settle()
		if not held_in_fall or (not starting_fall and animator.current_animation_position > 0.0):
			terrain.settle(self)
		return
	terrain.release_live()
	super.settle()
	terrain.skin = armed_skin if sceptre.visible else unarmed_skin
	terrain.settle_live(.0005)


func receive_action(request: Dictionary) -> bool:
	terrain.release_live()
	if not super.receive_action(request):
		return false
	terrain.skin = armed_skin if sceptre.visible else unarmed_skin
	if dead:
		terrain.prepare_collapse()
	return true


func begin_death_from(source: Node3D) -> float:
	var previous: RefCounted = source.terrain
	terrain.split = previous.split
	if source.sceptre.visible:
		terrain.skin = armed_skin
		terrain.remember_floor(self, previous.plane if not previous.plane.is_empty() else terrain.floor_under(self))
		return super.begin_death_from(source)
	if not source.dead:
		model.transform = source.model.transform
		previous = DisplayedPose.new()
		previous.plane = source.terrain.plane
	return terrain.begin_from_source(self, source, previous, false)


func corpse_snapshot_floor() -> float:
	return terrain.snapshot_floor(self)
