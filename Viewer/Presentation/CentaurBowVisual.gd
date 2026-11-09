extends "res://Presentation/ArchiveGestureVisual.gd"
## The exact server equipment record owns the bow and its dye.

const Hue := preload("res://Presentation/HumanHue.gd")
const BOW_SOURCE := "res://local-art/creatures/centaur-bow/weapon-bow-original.gltf"
const BOW_GRIP := Vector3(-0.00084, 0.02968, -0.00540)

static var source_bow: PackedScene
var bow: Node3D
var bow_mesh: MeshInstance3D
var left_wrist := -1
var left_fingertips := -1
var bow_hue := -1
var bow_id := 0

func _ready() -> void:
	super._ready()
	# This rig names the human arms as ponytail chains. Its ordinary Hand
	# joints belong to the front hooves.
	left_wrist = skeleton.find_bone("bip01 ponytail23")
	left_fingertips = skeleton.find_bone("bip01 ponytail24")
	assert(left_wrist >= 0 and left_fingertips >= 0 and skeleton.get_bone_parent(left_fingertips) == left_wrist)
	animator.mixer_applied.connect(sync_bow)
	contact.modification_processed.connect(sync_bow)

func set_equipment(worn: Array) -> void:
	var item: Dictionary = {}
	for candidate: Dictionary in worn:
		if int(candidate.get("layer", 0)) == 2 and int(candidate.get("id", 0)) in [0x13b1, 0x13b2]:
			item = candidate
			break
	bow_id = int(item.get("id", 0))
	if item.is_empty():
		if is_instance_valid(bow): bow.hide()
		return
	if not is_instance_valid(bow):
		if source_bow == null:
			var document := GLTFDocument.new()
			var state := GLTFState.new()
			if document.append_from_file(ProjectSettings.globalize_path(BOW_SOURCE), state) != OK: return
			var model_bow := document.generate_scene(state) as Node3D
			source_bow = PackedScene.new()
			source_bow.pack(model_bow)
			model_bow.free()
		bow = source_bow.instantiate()
		bow.name = "ThirdDawnBow"
		add_child(bow)
		bow_mesh = bow.find_children("*", "MeshInstance3D", true, false)[0]
	var next_hue := int(item.get("hue", 0))
	if bow_hue != next_hue:
		bow_hue = next_hue
		var base := bow_mesh.mesh.surface_get_material(0) as StandardMaterial3D
		bow_mesh.set_surface_override_material(0, Hue.material(base, bow_hue))
	bow.visible = not dead
	sync_bow()

func sync_bow() -> void:
	if not is_instance_valid(bow) or bow_id == 0: return
	bow.visible = not dead
	if dead: return
	var palm := left_palm()
	var forward := global_basis.z.normalized()
	var lateral := global_basis.x.normalized()
	var length_y := clampf((palm.y - global_position.y - 0.12) / 0.96, 0.0, 0.94)
	var carry := (forward * .91 - lateral * .34).normalized()
	var limb := carry * sqrt(1.0 - length_y * length_y) + Vector3.UP * length_y
	var thickness := (-forward).cross(limb).normalized()
	var fit := Basis(thickness, limb.cross(thickness).normalized(), limb)
	bow.global_transform = Transform3D(fit, palm - fit * BOW_GRIP)

func left_palm() -> Vector3:
	var wrist := skeleton.get_bone_global_pose(left_wrist).origin
	var fingertips := skeleton.get_bone_global_pose(left_fingertips).origin
	return skeleton.to_global(wrist.lerp(fingertips, 0.46))
