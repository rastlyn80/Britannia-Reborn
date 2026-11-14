# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SmallSnakeVisual.gd"

const PerchToes := ["bip01 l toe1nub", "bip01 r toe1nub"]

var toes := PackedInt32Array()
var model_origin := Vector3.ZERO


func _ready() -> void:
	super._ready()
	contact.active = false
	model_origin = model.position
	for toe: String in PerchToes:
		var joint := skeleton.find_bone(toe)
		assert(joint >= 0, "The perch parrot requires its original toe joints")
		toes.append(joint)
	update_landmarks()


func _physics_process(_delta: float) -> void:
	pass


func update_landmarks() -> void:
	if toes.size() == PerchToes.size():
		model.position = model_origin
		if not dead:
			var grip := Vector3.ZERO
			for joint: int in toes:
				grip += to_local(skeleton.to_global(skeleton.get_bone_global_pose(joint).origin))
			model.position -= grip / toes.size()
	super.update_landmarks()
