# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/MeasuredCreatureVisual.gd"

const Hue := preload("res://Presentation/HumanHue.gd")
const Footing := preload("res://Presentation/SourceSkeletonGround.gd")
const BowPath := "res://local-art/creatures/centaur-bow/weapon-bow-original.gltf"
const Grip := Vector3(-0.00084, 0.02968, -0.00540)

var bow_mount: BoneAttachment3D
var bow_mesh: MeshInstance3D


func _ready() -> void:
	super._ready()
	Footing.attach(self)
	contact.modification_processed.connect(update_landmarks)
	var grip := skeleton.find_bone("cp_grasp_lhand")
	if grip < 0 or not ResourceLoader.exists(BowPath, "PackedScene"):
		return
	bow_mount = BoneAttachment3D.new()
	bow_mount.name = "OrcScoutBowGrip"
	bow_mount.bone_idx = grip
	skeleton.add_child(bow_mount)
	var prop := (load(BowPath) as PackedScene).instantiate() as Node3D
	bow_mount.add_child(prop)
	var orientation := Basis(Vector3.RIGHT, PI * .5).scaled(Vector3.ONE / skeleton.global_basis.x.length())
	prop.transform = Transform3D(orientation, -(orientation * Grip))
	bow_mesh = prop.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	bow_mount.hide()


func _physics_process(_delta: float) -> void:
	if not dead:
		contact.sample(get_world_3d().direct_space_state, global_position)


func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if dead:
		contact.prepare_death()
	return true


func begin_death_from(source: Node3D) -> float:
	return contact.death.enter(self, source)


func corpse_snapshot_floor() -> float:
	return contact.death.snapshot_floor(self)


func set_equipment(worn: Array) -> void:
	if not is_instance_valid(bow_mount):
		return
	bow_mount.hide()
	for item: Dictionary in worn:
		if int(item.get("layer", 0)) != 2 or int(item.get("id", 0)) not in [0x13B1, 0x13B2]:
			continue
		var material := bow_mesh.mesh.surface_get_material(0) as StandardMaterial3D
		bow_mesh.set_surface_override_material(0, Hue.material(material, int(item.get("hue", 0))))
		bow_mount.show()
		return
