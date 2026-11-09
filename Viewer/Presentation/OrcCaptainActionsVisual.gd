extends "res://Presentation/TerathanActionsVisual.gd"

func _ready() -> void:
	super._ready()
	var axe := model.find_child("OrcCaptainAxe", true, false) as MeshInstance3D
	assert(axe != null and axe.has_meta("source_visual_prop"))
	var prop := Ground.skin_points(axe, skeleton)
	# Keep the cached body and prop skins immutable. The fall and the standing
	# gestures use one support envelope with both binding tables.
	skin = skin.duplicate(true)
	var first_prop_bind: int = skin.bones.size()
	skin.bones.append_array(prop.bones)
	skin.bind_poses.append_array(prop.bind_poses)
	for surface: Dictionary in prop.surfaces:
		var merged := surface.duplicate(true)
		var bindings: PackedInt32Array = merged.bindings
		for index in bindings.size():
			bindings[index] += first_prop_bind
		merged.bindings = bindings
		skin.surfaces.append(merged)
	skin.source_vertices += prop.source_vertices
	skin.unique_vertices += prop.unique_vertices
	fall.skin = skin

func set_hue(value: int) -> void:
	super.set_hue(value)
	if model == null:
		return
	var axe := model.find_child("OrcCaptainAxe", true, false) as MeshInstance3D
	if axe != null:
		for surface in axe.mesh.get_surface_count():
			axe.set_surface_override_material(surface, null)
