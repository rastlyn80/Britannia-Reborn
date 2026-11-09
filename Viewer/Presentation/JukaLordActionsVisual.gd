extends "res://Presentation/SourceJukaLordVisual.gd"

const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const GESTURES := ["BackhandStep", "ArmoredBrace", "ArmorGlance"]

func _ready() -> void:
	super._ready()
	contact.modification_processed.connect(clear_gesture_floor)

func clear_gesture_floor() -> void:
	if current_clip not in GESTURES or not contact.contacts.has(0):
		return
	var plane: Dictionary = contact.contacts[0]
	var normal: Vector3 = plane.normal
	if normal.y <= 0.75:
		return
	var gap := Ground.minimum_plane_gap(support_skin, skeleton, skeleton.global_transform, plane.position, normal)
	model.global_position.y += clampf((0.002 - gap) / normal.y, 0.0, 0.012)
	update_bow()
