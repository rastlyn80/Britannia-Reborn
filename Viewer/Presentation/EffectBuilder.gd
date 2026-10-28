extends RefCounted
# Magic and fire effects UO draws as animated sprites (teleporters, magic
# fields, sparkles, moongates, glowing runes, open fire): built as emissive
# particles and glows, with a light where the effect would cast one.
# preset -> [kind, colour, size (m), light energy]
const PRESETS := {
	"teleporter":["swirl","7fb8ff",0.9,0.6],
	"moongate":["gate","5f8dff",2.3,1.4],
	"red moongate":["gate","ff5f4a",2.3,1.4],
	"field of fire":["flames","ff8a2a",1.0,1.2],
	"fire":["flames","ff8a2a",0.8,1.4],
	"wall of fire":["flames","ff8a2a",1.0,1.2],
	"field of energy":["field","8fb4ff",1.0,0.8],
	"field of paralysis":["field","ffe680",1.0,0.6],
	"field of poison":["field","7bff6a",1.0,0.5],
	"sparkle":["sparkles","fff4c8",0.6,0.0],
	"magical sparkles":["sparkles","c8dcff",0.7,0.0],
	"glow":["sparkles","ffe7a8",0.5,0.3],
	"glowing rune":["rune","66b8ff",0.7,0.4],
	"arcanecircle south":["rune","9a6bff",1.0,0.5],
	"death vortex":["swirl","6a2a8a",1.0,0.4],
	"chaos":["swirl","b02a40",0.9,0.4],
	"energy":["swirl","8fb4ff",0.8,0.6],
	"whirlpool":["swirl","9ccfd8",1.4,0.0],
	"web":["web","ffffff",1.3,0.0],
	"pentagram":["rune","c0201a",1.0,0.4],
	"wisp":["sparkles","9fd8ff",0.5,0.8],
	"gas trap":["field","9ad04a",0.8,0.2],
	"fizzle":["sparkles","c8c8c8",0.4,0.0],
	"alchemical symbol":["rune","e0b040",0.8,0.3],
	"rune":["rune","66b8ff",0.5,0.2],
	"sacrificial alter":["rune","a01810",1.0,0.4],
}
static var materials := {}

static func preset_for(name: String) -> String:
	var n := name.to_lower().strip_edges()
	if PRESETS.has(n): return n
	if n.ends_with("moongate"): return "moongate"
	if n in ["small web","spiderweb","egg case web"]: return "web"
	return ""

static func _material(key: String, color: Color, energy: float) -> StandardMaterial3D:
	if not materials.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES if key.ends_with("/p") else BaseMaterial3D.BILLBOARD_DISABLED
		m.albedo_color = Color(color.r,color.g,color.b,0.85)
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = energy
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.vertex_color_use_as_albedo = true
		if key.ends_with("/p"):
			# Soft round mote: a radial falloff, never a hard square sprite.
			var falloff := Gradient.new()
			falloff.set_color(0,Color(1,1,1,1))
			falloff.add_point(0.35,Color(1,1,1,0.6))
			falloff.set_color(falloff.get_point_count()-1,Color(1,1,1,0))
			var dot := GradientTexture2D.new()
			dot.gradient = falloff
			dot.fill = GradientTexture2D.FILL_RADIAL
			dot.fill_from = Vector2(0.5,0.5)
			dot.fill_to = Vector2(1.0,0.5)
			dot.width = 64
			dot.height = 64
			m.albedo_texture = dot
		materials[key] = m
	return materials[key]

static func _particles(parent: Node3D, preset: String, color: Color, amount: int, lifetime: float, box: Vector3, velocity: Vector3, spread: float, size: float) -> void:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.visibility_aabb = AABB(-box-Vector3.ONE,box*2+Vector3.ONE*3)
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = box
	process.direction = velocity.normalized() if velocity.length() > 0 else Vector3.UP
	process.initial_velocity_min = velocity.length()*0.6
	process.initial_velocity_max = velocity.length()*1.2
	process.spread = spread
	process.gravity = Vector3.ZERO
	process.scale_min = 0.6
	process.scale_max = 1.2
	var fade := Gradient.new()
	fade.set_color(0,Color(1,1,1,0))
	fade.add_point(0.2,Color(1,1,1,1))
	fade.set_color(fade.get_point_count()-1,Color(1,1,1,0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	p.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(size,size)
	quad.material = _material(preset+"/p",color,2.4)
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)

static func _disc(parent: Node3D, preset: String, color: Color, radius: float, y: float, vertical := false) -> void:
	var disc := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.01
	mesh.radial_segments = 32
	disc.mesh = mesh
	var m := _material(preset+"/disc",color,1.6).duplicate() as StandardMaterial3D
	m.albedo_color = Color(color.r,color.g,color.b,0.35)
	disc.material_override = m
	disc.position.y = y
	if vertical: disc.rotation.x = PI/2
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(disc)

static func build(preset: String) -> Node3D:
	var spec: Array = PRESETS[preset]
	var kind: String = spec[0]
	var color := Color(str(spec[1]))
	var size := float(spec[2])
	var root := Node3D.new()
	root.set_meta("model","effect")
	match kind:
		"swirl":
			_disc(root,preset,color,size*0.5,0.02)
			_particles(root,preset,color,40,1.6,Vector3(size*0.4,0.05,size*0.4),Vector3(0,0.6,0),25.0,0.08)
		"gate":
			# A standing oval of light (moongate): a flattened disc and rising motes.
			var gate := Node3D.new()
			gate.scale = Vector3(0.55,1.0,1.0)
			gate.position.y = size*0.5
			_disc(gate,preset,color,size*0.5,0.0,true)
			root.add_child(gate)
			_particles(root,preset,color,60,1.4,Vector3(size*0.25,size*0.45,0.05),Vector3(0,0.4,0),40.0,0.07)
		"flames":
			_particles(root,preset,color,48,0.9,Vector3(size*0.35,0.05,size*0.35),Vector3(0,1.3,0),12.0,0.28)
			_particles(root,preset+"core",Color("ffd060"),24,0.6,Vector3(size*0.2,0.03,size*0.2),Vector3(0,0.9,0),8.0,0.18)
		"field":
			_particles(root,preset,color,50,1.2,Vector3(size*0.45,0.6,0.08),Vector3(0,0.3,0),60.0,0.1)
		"sparkles":
			_particles(root,preset,color,24,1.2,Vector3(size*0.4,size*0.4,size*0.4),Vector3(0,0.15,0),180.0,0.05)
		"web":
			# Strung diagonally across the cell corner, from the floor up.
			var quad := MeshInstance3D.new()
			var plane := QuadMesh.new()
			plane.size = Vector2(size,size)
			quad.mesh = plane
			var m := ShaderMaterial.new()
			m.shader = preload("res://Presentation/Web.gdshader")
			quad.material_override = m
			quad.position = Vector3(-0.2,size*0.55,-0.2)
			quad.rotation.y = PI/4
			quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(quad)
		"rune":
			_disc(root,preset,color,size*0.45,0.015)
			_particles(root,preset,color,16,1.8,Vector3(size*0.3,0.02,size*0.3),Vector3(0,0.35,0),10.0,0.05)
	if float(spec[3]) > 0.0:
		var light := OmniLight3D.new()
		light.light_color = color
		light.light_energy = float(spec[3])
		light.omni_range = 3.0+size*2.0
		light.position.y = 0.6
		light.shadow_enabled = false
		root.add_child(light)
	return root
