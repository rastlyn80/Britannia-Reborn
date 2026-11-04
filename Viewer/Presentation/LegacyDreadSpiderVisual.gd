extends "res://Presentation/CreatureVisual.gd"

var base_categories: Dictionary

func _ready() -> void:
	entry = entry.duplicate()
	base_categories = entry.get("classic_action_categories", {})
	super._ready()

func apply_identity(body: int, value: int, item: int = 0) -> void:
	if body != native_body:
		# Only body 11 has byte-identical source frames for slots 11 and 17.
		var body_categories: Dictionary = entry.get("classic_action_categories_by_body", {}).get(str(body), {})
		entry["classic_action_categories"] = base_categories.merged(body_categories, true)
	super.apply_identity(body, value, item)
