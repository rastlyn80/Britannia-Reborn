extends Node3D
# A ship afloat: the hull rides a slow swell (heave, roll and pitch), and when
# the boat is under way (MultiPresenter glides its root between 0xF6 steps)
# foam trails from the stern and spray curls off the bow. Only the visual
# "Hull" child moves; the root, its server position and the deck cells that
# carry passengers stay exact, and the swell is small at deck level.
var hull: Node3D
var length := 11.0
var beam := 5.0
var phase := 0.0
var last := Vector3.ZERO
var speed := 0.0
var wake: GPUParticles3D
var spray: Array[GPUParticles3D] = []

func setup(model: Node3D, ship_length: float, ship_beam: float, seed: int) -> void:
	hull = model
	length = ship_length
	beam = ship_beam
	phase = float(seed % 997)*0.37
	# Stern lantern: a warm light on a post at the taffrail, lit day and night.
	var lantern := Node3D.new()
	lantern.name = "SternLantern"
	lantern.position = Vector3(0,0.6+maxf(1.4,length*0.16),length*0.44)
	var glass := MeshInstance3D.new()
	var bulb := SphereMesh.new(); bulb.radius = 0.12; bulb.height = 0.3
	glass.mesh = bulb
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("ffd38a"); glow.emission_enabled = true; glow.emission = Color("ffb04a"); glow.emission_energy_multiplier = 3.0
	glass.material_override = glow
	lantern.add_child(glass)
	var light := OmniLight3D.new()
	light.light_color = Color("ffbf6a"); light.light_energy = 1.1; light.omni_range = 6.0
	lantern.add_child(light)
	hull.add_child(lantern)
	# Stern wake: foam patches laid flat on the water, left behind in world space.
	wake = _foam(48,3.2,Vector2(beam*0.5,0.9))
	wake.position = Vector3(0,0.03,length*0.48)
	add_child(wake)
	# Bow spray: two short curls either side of the stem.
	for side in [-1.0,1.0]:
		var curl := _foam(24,1.1,Vector2(0.7,0.5))
		curl.position = Vector3(side*beam*0.22,0.05,-length*0.45)
		(curl.process_material as ParticleProcessMaterial).direction = Vector3(side,0.25,0.4)
		(curl.process_material as ParticleProcessMaterial).initial_velocity_min = 0.6
		(curl.process_material as ParticleProcessMaterial).initial_velocity_max = 1.2
		add_child(curl)
		spray.append(curl)

func _ready() -> void:
	last = global_position

func _process(delta: float) -> void:
	if hull == null: return
	var now := global_position
	var moved := Vector2(now.x-last.x,now.z-last.z).length()/maxf(delta,0.001)
	last = now
	speed = lerpf(speed,moved,1.0-exp(-4.0*delta))
	phase += delta
	# Swell: long, slow and small; bigger ships move less.
	var calm := clampf(11.0/length,0.6,1.0)
	hull.position.y = sin(phase*0.9)*0.05*calm
	hull.rotation.z = sin(phase*0.7+1.3)*deg_to_rad(1.6)*calm
	hull.rotation.x = sin(phase*0.55+0.4)*deg_to_rad(0.9)*calm-clampf(speed*0.004,0.0,0.02)
	var under_way := speed > 0.4
	wake.emitting = under_way
	for curl in spray: curl.emitting = under_way

static var foam_texture: Texture2D
# A soft round puff, shared by foam, spray and chimney smoke.
static func soft_dot() -> Texture2D:
	if foam_texture == null:
		var dot := GradientTexture2D.new()
		dot.fill = GradientTexture2D.FILL_RADIAL
		dot.fill_from = Vector2(0.5,0.5)
		dot.fill_to = Vector2(1.0,0.5)
		var soft := Gradient.new()
		soft.set_color(0,Color(1,1,1,1))
		soft.set_color(1,Color(1,1,1,0))
		dot.gradient = soft
		foam_texture = dot
	return foam_texture

static func _foam(amount: int, life: float, size: Vector2) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = life
	particles.local_coords = false
	particles.emitting = false
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(size.x,0.02,size.y*0.5)
	process.direction = Vector3(0,0,1)
	process.spread = 25.0
	process.initial_velocity_min = 0.1
	process.initial_velocity_max = 0.35
	process.gravity = Vector3(0,-0.4,0)
	process.scale_min = 0.6
	process.scale_max = 1.4
	var grow := Curve.new()
	grow.add_point(Vector2(0,0.4)); grow.add_point(Vector2(1,1.8))
	var grow_texture := CurveTexture.new(); grow_texture.curve = grow
	process.scale_curve = grow_texture
	var fade := Gradient.new()
	fade.set_color(0,Color(1,1,1,0.75))
	fade.set_color(1,Color(1,1,1,0.0))
	var ramp := GradientTexture1D.new(); ramp.gradient = fade
	process.color_ramp = ramp
	particles.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.7,0.7)
	quad.orientation = PlaneMesh.FACE_Y
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.vertex_color_use_as_albedo = true
	look.albedo_color = Color("eef6f8")
	look.albedo_texture = soft_dot()
	quad.material = look
	particles.draw_pass_1 = quad
	return particles
