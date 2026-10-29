extends Node3D
# Draws the server's graphic effects (Effects module: 0x70/0xC0/0xC7) in 3D:
# moving bolts fly from source to target and burst if they explode, fixed
# effects bloom at a spot or on a creature for their duration, lightning
# strikes from the sky. Colour comes from the server hue when given, else from
# the effect art's family (fire, energy, poison, holy, smoke, magic).
var scene: Node3D
const FAMILIES := [
	[0x36b0,0x36bd,"fire"],[0x36cb,0x36fe,"fire"],[0x3709,0x3727,"fire"],[0x398c,0x39a0,"fire"],
	[0x3728,0x3739,"smoke"],[0x373a,0x3749,"holy"],[0x374a,0x3759,"poison"],[0x375a,0x3769,"holy"],
	[0x376a,0x3778,"magic"],[0x3779,0x3788,"poison"],[0x3789,0x379e,"energy"],[0x379f,0x37b8,"energy"],
	[0x3915,0x3946,"poison"],[0x3947,0x3966,"energy"],[0x3967,0x3990,"magic"]]
const COLOURS := {"fire":Color(1.0,0.55,0.18),"smoke":Color(0.55,0.55,0.58),"holy":Color(1.0,0.92,0.6),"poison":Color(0.45,0.95,0.35),"energy":Color(0.45,0.7,1.0),"magic":Color(0.75,0.5,1.0)}

func configure(world_scene: Node3D) -> void:
	scene = world_scene
	scene.game.module("effects").spawned.connect(present)

static func family(graphic: int) -> String:
	for entry in FAMILIES:
		if graphic >= entry[0] and graphic <= entry[1]: return entry[2]
	return "magic"

static func colour(effect: Dictionary) -> Color:
	var hue := int(effect.get("hue",0))&0x3fff
	if hue > 1: return preload("res://Network/Artwork.gd").color(hue,COLOURS[family(int(effect.get("graphic",0)))])
	return COLOURS[family(int(effect.get("graphic",0)))]

# Where a serial stands now (chest height for creatures), else the tile.
func _point(serial: int, tile: Vector3i, chest := true) -> Vector3:
	if scene.avatars.has(serial): return scene.avatars[serial].global_position+Vector3.UP*(1.2 if chest else 0.1)
	if scene.world_items.nodes.has(serial): return scene.world_items.nodes[serial].global_position+Vector3.UP*0.4
	return scene.entity_point(tile.x,tile.y,tile.z)+Vector3.UP*(1.0 if chest else 0.1)

func present(effect: Dictionary) -> void:
	if scene == null or scene.game.phase != "world": return
	var tint := colour(effect)
	match str(effect.kind):
		"moving": _bolt(effect,tint)
		"lightning": _lightning(_point(int(effect.target),effect.to,false),tint)
		"fixed_mobile": _bloom(_point(int(effect.target if int(effect.target) else effect.source),effect.from),tint,effect,int(effect.target if int(effect.target) else effect.source))
		_: _bloom(_point(0,effect.from,false),tint,effect)

# A soft round spot (bright core, fading edge) shared by every spark.
static var soft: Texture2D
static func soft_spot() -> Texture2D:
	if soft == null:
		var fade := Gradient.new()
		fade.set_color(0,Color(1,1,1,1))
		fade.add_point(0.35,Color(1,1,1,0.55))
		fade.set_color(fade.get_point_count()-1,Color(1,1,1,0))
		var texture := GradientTexture2D.new()
		texture.gradient = fade
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5,0.5)
		texture.fill_to = Vector2(1.0,0.5)
		texture.width = 64
		texture.height = 64
		soft = texture
	return soft

static func _glow(tint: Color, energy := 4.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = soft_spot()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = tint
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = energy
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	return material

# Sparks drifting up and out, coloured and fading.
static func sparks(tint: Color, amount: int, lifetime: float, spread: float, speed := 1.0) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.explosiveness = 0.15
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = spread
	process.direction = Vector3.UP
	process.spread = 70
	process.initial_velocity_min = 0.3*speed
	process.initial_velocity_max = 1.2*speed
	process.gravity = Vector3(0,0.6,0)
	process.scale_min = 0.6
	process.scale_max = 1.6
	var fade := Gradient.new()
	fade.set_color(0,Color(tint,1.0))
	fade.set_color(1,Color(tint.lightened(0.3),0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	particles.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.16,0.16)
	quad.material = _glow(tint)
	particles.draw_pass_1 = quad
	return particles

func _light(at: Vector3, tint: Color, energy: float, reach: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = tint
	light.light_energy = energy
	light.omni_range = reach
	light.position = at
	add_child(light)
	return light

func _expire(node: Node, seconds: float) -> void:
	get_tree().create_timer(seconds).timeout.connect(func(): if is_instance_valid(node): node.queue_free())

func _bolt(effect: Dictionary, tint: Color) -> void:
	var from := _point(int(effect.source),effect.from)
	var to := _point(int(effect.target),effect.to)
	var core := MeshInstance3D.new()
	core.mesh = SphereMesh.new()
	core.mesh.radius = 0.1
	core.mesh.height = 0.2
	var material := _glow(tint,6.0)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	core.material_override = material
	core.position = from
	add_child(core)
	var trail := sparks(tint,40,0.45,0.06,0.4)
	trail.local_coords = false
	core.add_child(trail)
	var glow := OmniLight3D.new()
	glow.light_color = tint
	glow.light_energy = 1.6
	glow.omni_range = 3.0
	core.add_child(glow)
	var seconds := clampf(from.distance_to(to)/(6.0+float(effect.speed)),0.15,1.6)
	var flight := create_tween()
	flight.tween_property(core,"position",to,seconds)
	flight.tween_callback(func():
		if effect.explodes: _burst(to,tint)
		core.queue_free())

func _burst(at: Vector3, tint: Color) -> void:
	var burst := sparks(tint,90,0.7,0.25,3.0)
	burst.one_shot = true
	burst.explosiveness = 0.9
	burst.position = at
	add_child(burst)
	burst.emitting = true
	var flash := _light(at,tint,4.0,6.0)
	create_tween().tween_property(flash,"light_energy",0.0,0.5)
	_expire(burst,1.2)
	_expire(flash,0.6)

func _bloom(at: Vector3, tint: Color, effect: Dictionary, follow := 0) -> void:
	var seconds := clampf(float(effect.get("duration",10))*0.1,0.6,3.0)
	var bloom := sparks(tint,70,0.9,0.35,1.2)
	bloom.position = at
	add_child(bloom)
	# A soft halo at the heart of the effect.
	var halo := MeshInstance3D.new()
	halo.mesh = QuadMesh.new()
	halo.mesh.size = Vector2(1.4,1.4)
	halo.material_override = _glow(Color(tint,0.55),2.5)
	bloom.add_child(halo)
	var light := _light(at+Vector3.UP*0.3,tint,2.2,4.5)
	if follow and scene.avatars.has(follow):
		var target: Node3D = scene.avatars[follow]
		var track := func():
			if is_instance_valid(target) and is_instance_valid(bloom):
				bloom.global_position = target.global_position+Vector3.UP*1.0
				light.global_position = bloom.global_position
		get_tree().process_frame.connect(track)
		get_tree().create_timer(seconds+0.9).timeout.connect(func(): get_tree().process_frame.disconnect(track))
	get_tree().create_timer(seconds).timeout.connect(func(): if is_instance_valid(bloom): bloom.emitting = false)
	create_tween().tween_property(light,"light_energy",0.0,seconds+0.4)
	_expire(bloom,seconds+1.0)
	_expire(light,seconds+0.5)

func _lightning(at: Vector3, tint: Color) -> void:
	var bolt := MeshInstance3D.new()
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := at+Vector3(randf_range(-1,1),14,randf_range(-1,1))
	var previous := top
	for i in range(1,9):
		var point := top.lerp(at,i/8.0)+(Vector3(randf_range(-0.5,0.5),0,randf_range(-0.5,0.5)) if i < 8 else Vector3.ZERO)
		var side := Vector3(0.06,0,0.06)
		for vertex in [previous-side,previous+side,point+side,previous-side,point+side,point-side]: tool.add_vertex(vertex)
		previous = point
	bolt.mesh = tool.commit()
	var material := _glow(Color(0.85,0.9,1.0),8.0)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	bolt.material_override = material
	add_child(bolt)
	var flash := _light(at+Vector3.UP*2,Color(0.8,0.85,1.0),8.0,14.0)
	create_tween().tween_property(flash,"light_energy",0.0,0.35)
	_burst(at+Vector3.UP*0.2,tint)
	_expire(bolt,0.25)
	_expire(flash,0.4)
