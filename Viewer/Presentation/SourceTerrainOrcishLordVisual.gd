# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/MeasuredCreatureVisual.gd"

const Footing := preload("res://Presentation/SourceSkeletonGround.gd")
var axe_arm: Array[int] = []


func _ready() -> void:
	super._ready()
	Footing.attach(self)
	contact.modification_processed.connect(update_landmarks)
	var axe := model.find_child("OrcLordAxe", true, false) as MeshInstance3D
	assert(axe != null and axe.skin != null)
	for suffix: String in ["r hand", "r forearm", "r upperarm"]:
		var joint: int = contact.bone(suffix)
		assert(joint >= 0)
		axe_arm.append(joint)
	contact.support_appendages = clear_axe.bind(axe)
	set_hue(native_hue)


func _physics_process(_delta: float) -> void:
	if not dead:
		contact.sample(get_world_3d().direct_space_state, global_position)


func play_gait(moving: bool, speed: float) -> void:
	if moving and current_clip in ["Fidget", "Fidget2"]:
		action_remaining = 0.0
	super.play_gait(moving, speed)


func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if dead:
		contact.prepare_death()
	return true


func begin_death_from(source: Node3D) -> float:
	return contact.death.enter(self, source)


func corpse_snapshot_floor() -> float:
	return contact.death.snapshot_floor(self)



func clear_axe(axe: MeshInstance3D) -> void:
	var skin: Array[Dictionary] = [contact.surfaces[axe]]
	for attempt in 2:
		for joint: int in axe_arm:
			skeleton.force_update_all_bone_transforms()
			var hit: Dictionary = contact.step_conflict(float(contact.ground.position.y), contact.floor_query, skin)
			if hit.is_empty():
				return
			contact.rotate_toward_surface(joint, hit.point, hit.normal, hit.lift * hit.normal.y)


func set_hue(value: int) -> void:
	super.set_hue(value)
	if model == null:
		return
	var axe := model.find_child("OrcLordAxe", true, false) as MeshInstance3D
	if axe != null:
		axe.set_surface_override_material(0, null)
