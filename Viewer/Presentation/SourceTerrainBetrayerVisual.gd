# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/OccurrenceCreatureVisual.gd"

var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()
var poison_socket := -1


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(1.65, 1.4))
	poison_socket = skeleton.find_bone("bip01 l hand")
	animator.mixer_applied.connect(settle_pose)
	contact.modification_processed.connect(settle_pose)


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	super._physics_process(delta)
	settle_pose()


func settle_pose() -> void:
	if not terrain.plane.is_empty():
		if not dead:
			terrain.settle_live(.0005)
		elif animator.current_animation_position > 0.0 or not terrain.blend_pose.is_empty():
			terrain.settle(self)


func receive_action(request: Dictionary) -> bool:
	if not dead:
		terrain.release_live()
	if not super.receive_action(request):
		return false
	if dead:
		terrain.prepare_collapse()
	return true


func begin_death_from(source: Node3D) -> float:
	return terrain.begin_collapse(source)


func corpse_snapshot_floor() -> float:
	return terrain.snapshot_floor(self)


func poison_gas_origin() -> Vector3:
	skeleton.force_update_all_bone_transforms()
	return skeleton.to_global(skeleton.get_bone_global_pose(poison_socket).origin)
