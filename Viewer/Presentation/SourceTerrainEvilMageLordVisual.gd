# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/EvilMageLordActionsVisual.gd"

const DisplayedPose := preload("res://Presentation/CreatureFallPlayback.gd")
var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()
var displayed_costume: Array = []
var released_hit_contact := false


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(1.2, 1.4))
	contact.modification_processed.connect(settle_contact)


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	if terrain.split:
		align_tread_height()
	var release_hit := terrain.split and current_clip == "Hit"
	if release_hit:
		contact.enabled = false
	elif released_hit_contact:
		contact.enabled = true
	released_hit_contact = release_hit
	super._physics_process(delta)
	if not contact.enabled:
		settle_living()


func _process(delta: float) -> void:
	super._process(delta)
	if not dead:
		displayed_costume = server_equipment


func apply_blend_ground() -> void:
	if dead and not terrain.plane.is_empty():
		terrain.settle(self)
		update_landmarks()
		return
	if terrain.actor != null:
		terrain.release_live()
	super.apply_blend_ground()
	if terrain.actor != null and terrain.split:
		align_tread_height()


func align_tread_height() -> void:
	# One body height avoids fighting the independent foot corrections on a split tread.
	model.position.y = source_model_position.y
	contact.base_model_y = model.position.y


func settle_contact() -> void:
	if contact.enabled:
		# SourceMageSupport restores its calibrated model height before solving.
		terrain.live_lift = 0.0
		settle_living()


func settle_living() -> void:
	terrain.settle_live(.0005)
	update_landmarks()


func receive_action(request: Dictionary) -> bool:
	terrain.release_live()
	if not super.receive_action(request):
		return false
	if dead:
		terrain.prepare_collapse()
	return true


func begin_death_from(source: Node3D) -> float:
	# Native death can remove the worn item records before sending the fall.
	# Match the costume from the preceding displayed frame.
	if not source.displayed_costume.is_empty():
		set_equipment(source.displayed_costume)
	var previous: RefCounted = source.terrain
	terrain.split = previous.split
	if not source.dead:
		model.transform = source.model.transform
		previous = DisplayedPose.new()
		previous.plane = source.terrain.plane
	return terrain.begin_from_source(self, source, previous, false)


func corpse_snapshot_floor() -> float:
	return terrain.snapshot_floor(self)
