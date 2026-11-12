# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedSnowElementalVisual.gd"

const Footing := preload("res://Presentation/SourceSnowElementalContact.gd")
const PackRise := "SnowElementalPackRise"


func _ready() -> void:
	super._ready()
	var mesh: MeshInstance3D = contact.surface
	contact.free()
	contact = Footing.new()
	skeleton.add_child(contact)
	contact.bind(self, mesh, null)
	contact.modification_processed.connect(update_landmarks)


func _physics_process(_delta: float) -> void:
	if not dead:
		contact.sample(get_world_3d().direct_space_state, global_position)


func play_gait(moving: bool, speed: float) -> void:
	if moving and current_clip in ["Fidget", PackRise]:
		action_remaining = 0.0
	super.play_gait(moving, speed)


func receive_action(request: Dictionary) -> bool:
	var accepted := super.receive_action(request)
	if accepted:
		if dead:
			contact.prepare_death()
		else:
			contact.enabled = true
	return accepted


func update_fitted_pose() -> void:
	if not dead:
		growth.apply(self, PackRise)
	update_landmarks()


func begin_death_from(source: Node3D) -> float:
	return contact.death.enter(self, source)


func corpse_snapshot_floor() -> float:
	return contact.death.snapshot_floor(self)
