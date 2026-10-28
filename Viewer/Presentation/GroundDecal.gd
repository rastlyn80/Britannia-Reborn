extends RefCounted
# Ground decals (leaf litter, snow, sand, dirt, mud, blood, spilled flour,
# stains) drawn with photoscanned surfaces (Art/Surfaces, CC0 Poly Haven) on a
# quad just above the ground, with an irregular outline per tile.
# preset -> [surface set, tint, coverage, speckle, square, roughness]
const PRESETS := {
	"leaves":["forest_leaves_02","ffffff",0.62,0.0,0.0,0.9],
	"snow":["snow_02","ffffff",1.12,0.0,1.0,0.7],
	"sand":["coast_sand_01","fff0d0",1.12,0.0,1.0,0.95],
	"dirt":["dirt","ffffff",0.75,0.75,0.0,0.95],
	"dirt patch":["stony_dirt_path","ffffff",0.6,0.0,0.0,0.95],
	"mud":["brown_mud_dry","8a6a50",0.55,0.0,0.0,0.6],
	"blood":["brown_mud_dry","4a0806",0.5,0.0,0.0,0.22],
	"spilled flour":["white_plaster_02","fbf6ea",0.7,0.9,0.0,0.95],
	"stain":["dirt","3a3530c0",0.6,0.0,0.0,0.8],
}
static var materials := {}

static func preset_for(name: String) -> String:
	var n := name.to_lower().strip_edges()
	return n if PRESETS.has(n) else ""

static func build(preset: String, cell: Vector2i) -> Node3D:
	var spec: Array = PRESETS[preset]
	var variant := posmod(cell.x*7+cell.y*13,4)
	var key := "%s/%d" % [preset,variant]
	if not materials.has(key):
		var material := ShaderMaterial.new()
		material.shader = preload("res://Presentation/GroundDecal.gdshader")
		preload("res://Presentation/SurfaceLibrary.gd").bind(material,"surface",str(spec[0]))
		material.set_shader_parameter("tint",Color(str(spec[1])))
		material.set_shader_parameter("coverage",float(spec[2]))
		material.set_shader_parameter("speckle",float(spec[3]))
		material.set_shader_parameter("square",float(spec[4]))
		material.set_shader_parameter("roughness",float(spec[5]))
		material.set_shader_parameter("seed",float(variant)*1.37)
		materials[key] = material
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.0,1.0)
	var mesh := MeshInstance3D.new()
	mesh.mesh = plane
	mesh.material_override = materials[key]
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.position.y = 0.012
	mesh.rotation.y = float(variant)*PI/2
	var root := Node3D.new()
	root.set_meta("model","decal")
	root.add_child(mesh)
	return root
