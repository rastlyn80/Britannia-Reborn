# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedOrcCaptainVisual.gd"

const DisplayedPose := preload("res://Presentation/CreatureFallPlayback.gd")
var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(2.5, 2.2))
	terrain.skin = skin
	contact.modification_processed.connect(settle)


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
		if animator.current_animation_position > 0.0 or not terrain.blend_pose.is_empty():
			terrain.settle(self)
	else:
		terrain.release_live()
		super.settle()
		terrain.settle_live(.0005)


func play_gait(moving: bool, speed: float) -> void:
	if moving and current_clip in ["CaptainAxeSignal", "CaptainAxeCheck"]:
		var request: Dictionary = get_meta("native_action", {})
		# A queued stock idle packet can precede a step on the same update.
		if request.get("protocol") == "classic" and request.get("action") in [17, 18] \
				and request.get("frames") == 5 and request.get("repeat_count") == 1 \
				and request.get("reverse") == false and request.get("repeat") == false and request.get("delay") == 1:
			action_remaining = 0.0
	super.play_gait(moving, speed)


func receive_action(request: Dictionary) -> bool:
	terrain.release_live()
	if not super.receive_action(request):
		return false
	if dead:
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
