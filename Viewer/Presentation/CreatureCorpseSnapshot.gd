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
	return {
		"body": visual.native_body,
		"scene": scene,
		"placement": visual.global_transform * Transform3D(Basis.IDENTITY, Vector3.UP * actor_floor),
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
	old.free()
	holder.add_child(frozen)
	frozen.global_transform = snapshot.placement
	var bounds: AABB = frozen.transform * frozen.get_meta("corpse_bounds")
	var shape := BoxShape3D.new()
	shape.size = bounds.size.max(Vector3.ONE * .15)
	pick.shape = shape
	pick.position = bounds.get_center()
	return true
