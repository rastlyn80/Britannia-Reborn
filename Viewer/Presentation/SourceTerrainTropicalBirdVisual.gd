# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/CreatureVisual.gd"

const Terrain := preload("res://Presentation/SourceTerrainMotion.gd")
var terrain := Terrain.new()


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(.55, .55))
	animator.mixer_applied.connect(settle_living)


func _physics_process(_delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	var space := get_world_3d().direct_space_state
	terrain.sample()
	if not terrain.plane.is_empty():
		var normal: Vector3 = global_basis.inverse() * terrain.plane.normal
		var tilt := Basis(Quaternion(Vector3.UP, normal.normalized()))
		model.basis = (tilt * source_model_basis).scaled_local(model.scale)
	contact.sample(space, global_position)
	settle_living()


func settle_living() -> void:
	if dead:
		terrain.settle(self)
		return
	terrain.settle_live()


func play_gait(moving: bool, speed: float) -> void:
	var request: Dictionary = get_meta("native_action", {})
	var resting := current_clip in ["Fidget", "Alert", "BirdGlance"]
	resting = resting or (current_clip == "BirdQuietSettle" and request.get("protocol") == "new"
		and int(request.get("type", -1)) == 5)
	if moving and resting:
		action_remaining = 0.0
	super.play_gait(moving, speed)


func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if dead:
		terrain.release_live()
		if terrain.plane.is_empty():
			terrain.remember_floor(self, terrain.floor_under(self))
	return true


func begin_death_from(source: Node3D) -> float:
	return terrain.enter_from_display(self, source)


func corpse_snapshot_floor() -> float:
	return terrain.snapshot_floor(self)
