extends RefCounted
# Streamed districts keep their baked tree materials; when a near district part
# draws owner-licensed trees, its surfaces switch to Foliage.gdshader, which
# drops the leaves of a tree that hides the player (World.gd feeds the globals).
# Runs at load time, so no re-bake is needed and offline art stays unchanged.
const SHADER := preload("res://Presentation/Foliage.gdshader")
static var swapped: Dictionary = {}

static func material_for(original: Material) -> Material:
	var standard := original as StandardMaterial3D
	if standard == null or standard.albedo_texture == null: return null
	if not "/local-art/trees/" in standard.albedo_texture.resource_path: return null
	var leaves := standard.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
	var key := standard.albedo_texture.resource_path+("/leaves" if leaves else "/bark")
	if not swapped.has(key):
		var material := ShaderMaterial.new()
		material.shader = SHADER
		material.set_shader_parameter("albedo_texture",standard.albedo_texture)
		material.set_shader_parameter("leaves",leaves)
		material.set_shader_parameter("roughness",standard.roughness)
		swapped[key] = material
	return swapped[key]

# One baked part (the part itself only: trees are top-level instanced parts).
static func adopt(part: Node) -> void:
	if not part is GeometryInstance3D: return
	if part.material_override:
		var replacement := material_for(part.material_override)
		if replacement: part.material_override = replacement
	if part is MeshInstance3D and part.mesh:
		for surface in part.mesh.get_surface_count():
			var replacement := material_for(part.get_active_material(surface))
			if replacement: part.set_surface_override_material(surface,replacement)
	elif part is MultiMeshInstance3D and part.material_override == null and part.get("source_mesh") is ArrayMesh:
		# InstancedPatch builds its MultiMesh from source_mesh in _ready; a tree
		# mesh carries bark and leaves, so it gets a copy with swapped surfaces
		# (owned by the part, freed with its district).
		var source: ArrayMesh = part.source_mesh
		var copy: ArrayMesh = null
		for surface in source.get_surface_count():
			var replacement := material_for(source.surface_get_material(surface))
			if replacement == null: continue
			if copy == null: copy = source.duplicate()
			copy.surface_set_material(surface,replacement)
		if copy: part.source_mesh = copy

# The player's chest, the camera and the clearance size, once per frame.
static func update(focus: Vector3, eye: Vector3, radius: float) -> void:
	RenderingServer.global_shader_parameter_set("clearance_focus",focus)
	RenderingServer.global_shader_parameter_set("clearance_eye",eye)
	RenderingServer.global_shader_parameter_set("clearance_radius",radius)
