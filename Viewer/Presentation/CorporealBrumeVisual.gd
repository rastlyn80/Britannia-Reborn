extends "res://Presentation/SourceAmorphousVisual.gd"

const Surface = preload("res://Presentation/CorporealBrumeSurface.gdshader")
var floor_lift := Vector3.ZERO

func _ready() -> void:
	super._ready()
	model.scale *= Vector3(0.81, 1.65, 0.81)
	default_model_scale = model.scale
	update_landmarks()

func _physics_process(delta: float) -> void:
	model.position -= floor_lift
	floor_lift = Vector3.ZERO
	super._physics_process(delta)
	if dead or contact.contacts.is_empty():
		return
	var hit: Dictionary = contact.contacts.values()[0]
	var gap := Ground.minimum_plane_gap(support_skin, skeleton, skeleton.global_transform, hit.position, hit.normal)
	if gap < 0.002:
		var before := model.position
		model.global_position += hit.normal * (0.002 - gap)
		floor_lift = model.position - before
	update_landmarks()

func set_hue(value: int) -> void:
	super.set_hue(value)
	if model == null or treatment != "modern":
		return
	var atlas := load("res://local-art/creatures/" + str(entry.source_atlas_texture)) as Texture2D
	var palette := preload("res://Presentation/HumanHue.gd").palette(value)
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var material := ShaderMaterial.new()
			material.shader = Surface
			material.set_shader_parameter("source_atlas", atlas)
			material.set_shader_parameter("hue_palette", palette)
			material.set_shader_parameter("use_hue", palette != null)
			material.set_shader_parameter("partial_hue", (value & 0x8000) != 0)
			mesh.set_surface_override_material(surface, material)
