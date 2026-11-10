# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/RabbitActionsVisual.gd"

class RabbitGestureGround extends "res://Presentation/ArchiveGestureGround.gd":
	var body_skin: Dictionary

	func bind(actor: Node3D) -> void:
		super.bind(actor)
		var body := actor.model.find_child("Rabbit", true, false) as MeshInstance3D
		body_skin = Ground.skin_points(body, actor.skeleton)

	func support(actor: Node3D) -> void:
		super.support(actor)
		if not applied:
			return
		var hit: Dictionary = actor.contact.contacts.values()[0]
		var normal: Vector3 = hit.normal
		var gap := Ground.minimum_plane_gap(body_skin, actor.skeleton,
			actor.skeleton.global_transform, hit.position, normal)
		if gap < .002:
			actor.model.global_position.y += (.002 - gap) / normal.y

var gesture_ground := RabbitGestureGround.new()

func _ready() -> void:
	super._ready()
	gesture_ground.bind(self)

func _physics_process(delta: float) -> void:
	gesture_ground.release(self)
	super._physics_process(delta)

func receive_action(request: Dictionary) -> bool:
	if request.get("protocol") == "new" and skeleton.has_node("NativeTunnelPose"):
		var kind := str(int(request.get("type", -1)))
		var modes: Dictionary = entry.get("enhanced_source_action_groups", {})
		if modes.get("0", {}).has(kind):
			return true
	return super.receive_action(request)
