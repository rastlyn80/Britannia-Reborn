extends "res://Presentation/SourceJukaVisual.gd"

const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Variants := preload("res://Presentation/CreatureModeZeroVariants.gd")
const GESTURES := ["AdvancingPalm", "HighRecoil", "LowRecoil", "JukaGlance"]

func _ready() -> void:
	super._ready()
	contact.modification_processed.connect(clear_gesture_floor)

func receive_action(request: Dictionary) -> bool:
	var base := entry
	entry = Variants.entry_for_packet(entry, request)
	var handled := super.receive_action(request)
	entry = base
	return handled

func clear_gesture_floor() -> void:
	if current_clip not in GESTURES or not contact.contacts.has(0):
		return
	var hit: Dictionary = contact.contacts[0]
	var normal: Vector3 = hit.normal
	if normal.y <= 0.75:
		return
	var gap := Ground.minimum_plane_gap(support_skin, skeleton, skeleton.global_transform, hit.position, normal)
	model.global_position.y += clampf((0.002 - gap) / normal.y, 0.0, 0.012)
