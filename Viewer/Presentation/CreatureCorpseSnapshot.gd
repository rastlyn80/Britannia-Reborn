extends RefCounted
## Preserve the displayed endpoint for a creature whose base follows terrain.
const Corpses = preload("res://Presentation/CorpseModels.gd")

static func capture(visual: Node3D, actor_floor: float) -> Dictionary:
	if not is_finite(actor_floor):
		return {}
	visual.set_meta("corpse_body", visual.native_body)
	visual.set_meta("native_hue", visual.native_hue)
	visual.set_meta("death_clip", visual.current_clip)
	var frozen := Corpses.freeze(visual)
	if frozen == null:
		return {}
	for child in frozen.get_children():
		child.owner = frozen
	var scene := PackedScene.new()
	var status := scene.pack(frozen)
	frozen.free()
	if status != OK:
		return {}
	var hidden_props: Array[StringName] = []
	var retained_prop_materials: Array[StringName] = []
	for prop: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
		if prop.is_visible_in_tree() and prop.get_meta("corpse_prop_keeps_material", false):
			retained_prop_materials.append(prop.name)
		elif not prop.is_visible_in_tree() and prop.get_meta("optional_corpse_visual_prop", false):
			hidden_props.append(prop.name)
	return {
		"body": visual.native_body,
		"scene": scene,
		"placement": visual.global_transform * Transform3D(Basis.IDENTITY, Vector3.UP * actor_floor),
		"hidden_props": hidden_props,
		"retained_prop_materials": retained_prop_materials,
	}

static func apply(holder: Node3D, snapshot: Dictionary) -> bool:
	if snapshot.is_empty() or int(holder.get_meta("corpse_body", 0)) != int(snapshot.body):
		return false
	var old := holder.get_node_or_null("CorpseVisual") as Node3D
	var pick := holder.get_node_or_null("PickBody/PickShape") as CollisionShape3D
	if old == null or pick == null or not pick.shape is BoxShape3D:
		return false
	var scene: PackedScene = snapshot.scene
	var frozen := scene.instantiate() as Node3D
	if frozen == null:
		return false
	if frozen.get_meta("native_hue") != old.get_meta("native_hue") and not use_current_materials(
			frozen, old, snapshot.get("hidden_props", []), snapshot.get("retained_prop_materials", [])):
		frozen.free()
		return false
	old.free()
	holder.add_child(frozen)
	frozen.global_transform = snapshot.placement
	var bounds: AABB = frozen.transform * frozen.get_meta("corpse_bounds")
	var shape := BoxShape3D.new()
	shape.size = bounds.size.max(Vector3.ONE * .15)
	pick.shape = shape
	pick.position = bounds.get_center()
	return true

static func use_current_materials(frozen: Node3D, current: Node3D, hidden_props: Array,
		retained_prop_materials: Array = []) -> bool:
	# A native corpse update may dye the same serial after its death pose was
	# captured. Keep that geometry and placement with the current appearance.
	for part: MeshInstance3D in current.get_children():
		# The default corpse can have a visual prop hidden in the captured pose.
		if not frozen.has_node(NodePath(part.name)) and part.name not in hidden_props:
			return false
	for part: MeshInstance3D in frozen.get_children():
		var latest := current.get_node_or_null(NodePath(part.name)) as MeshInstance3D
		# A fitted prop can differ from the default corpse's weapon and have its
		# own material when the server updates only the creature's hue.
		if latest == null and part.name in retained_prop_materials:
			continue
		if latest == null or latest.mesh.get_surface_count() != part.mesh.get_surface_count():
			return false
		for surface in part.mesh.get_surface_count():
			if part.mesh.surface_get_array_len(surface) != latest.mesh.surface_get_array_len(surface):
				return false
			part.set_surface_override_material(surface, latest.get_active_material(surface))
	frozen.set_meta("native_hue", current.get_meta("native_hue"))
	return true
