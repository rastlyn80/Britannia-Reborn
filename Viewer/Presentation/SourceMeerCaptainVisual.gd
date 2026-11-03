extends "res://Presentation/OccurrenceCreatureVisual.gd"

const GRIP := Vector3(0.0, 0.448, 0.0)
var crossbow: Node3D
var left_grasp := -1
var right_grasp := -1


func _ready() -> void:
	super._ready()
	left_grasp = skeleton.find_bone("cp_grasp_lhand")
	right_grasp = skeleton.find_bone("cp_grasp_rhand")
	animator.mixer_applied.connect(update_crossbow)


func set_equipment(worn: Array) -> void:
	var equipped := worn.any(func(item: Dictionary) -> bool:
		return int(item.get("id", 0)) in [0x0f4f, 0x0f50] and int(item.get("layer", 0)) == 2)
	if not equipped:
		if is_instance_valid(crossbow):
			crossbow.hide()
		return
	if not is_instance_valid(crossbow):
		var asset := load(str(entry.crossbow_asset)) as PackedScene
		crossbow = asset.instantiate() as Node3D
		crossbow.name = "OriginalCrossbow"
		add_child(crossbow)
	crossbow.show()
	update_crossbow()


func update_crossbow() -> void:
	if not is_instance_valid(crossbow) or not crossbow.visible:
		return
	var right := skeleton.to_global(skeleton.get_bone_global_pose(right_grasp).origin)
	var left := skeleton.to_global(skeleton.get_bone_global_pose(left_grasp).origin)
	var forward := global_basis.z - global_basis.y * 0.25
	if current_clip == "AttackXBow" and right.distance_squared_to(left) > 0.01:
		forward = left - right
	var backward := -forward.normalized()
	var lateral := backward.cross(global_basis.y).normalized()
	if lateral.is_zero_approx():
		lateral = global_basis.x.normalized()
	var basis := Basis(lateral, backward, lateral.cross(backward)).orthonormalized()
	crossbow.global_transform = Transform3D(basis, right - basis * GRIP)
