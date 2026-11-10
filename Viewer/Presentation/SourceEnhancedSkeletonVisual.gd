# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/CreatureVisual.gd"

const Assembly := "SkeletonAssemble"
var pieces: Node3D
var living_mesh: MeshInstance3D
var gesture_ground := AssemblyGround.new()

class AssemblyGround extends "res://Presentation/ArchiveGestureGround.gd":
	var points := {}

	func bind(actor: Node3D) -> void:
		super.bind(actor)
		for piece: MeshInstance3D in actor.pieces.get_children():
			points[piece] = piece.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]

	func support(actor: Node3D) -> void:
		if actor.current_clip != Assembly or not actor.pieces.visible:
			super.support(actor)
			return
		release(actor)
		if actor.dead or actor.contact.contacts.is_empty():
			return
		var hit: Dictionary = actor.contact.contacts.values()[0]
		var normal: Vector3 = hit.normal
		if normal.y < .75:
			return
		var gap := INF
		for piece: MeshInstance3D in points:
			if not piece.visible:
				continue
			var space := piece.global_transform
			var direction := space.basis.transposed() * normal
			var origin := (space.origin - hit.position as Vector3).dot(normal)
			for vertex: Vector3 in points[piece]:
				gap = minf(gap, vertex.dot(direction) + origin)
		if gap < .002:
			restore_pose = actor.model.transform
			applied = true
			actor.model.global_position.y += (.002 - gap) / normal.y

func _ready() -> void:
	super._ready()
	pieces = model.get_node("AssemblyPieces")
	living_mesh = model.find_child("Body", true, false)
	gesture_ground.bind(self)
	animator.mixer_applied.connect(restore_body)

func _physics_process(delta: float) -> void:
	gesture_ground.release(self)
	super._physics_process(delta)

func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	restore_body()
	return true

func restore_body() -> void:
	if current_clip != Assembly:
		living_mesh.visible = true
		pieces.visible = false
