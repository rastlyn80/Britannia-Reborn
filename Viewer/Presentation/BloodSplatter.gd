extends RefCounted
# Blood the server spills in a fight (ModernUO's Blood item): a projected
# decal that lies on whatever is under it (terrain, floors, steps), so it
# never floats or flickers, with a generated splatter: a dark pooled centre,
# a glossy wet rim (normal and roughness maps), flung droplets and streaks.
# It spreads in when it lands, with a short spray of drops; each blood item
# picks one of several variants and a turn, so no two spills match.
const IDS := [0x1645,0x122A,0x122B,0x122C,0x122D,0x122E,0x122F]
const SIZE := 256
const VARIANTS := 6
static var textures := {}

static func handles(id: int) -> bool:
	return id in IDS

static func build(serial: int, id: int) -> Node3D:
	var variant := posmod(serial*7+id,VARIANTS)
	var maps: Array = _maps(variant)
	var root := Node3D.new()
	root.name = "Blood"
	root.set_meta("model","blood")
	var decal := Decal.new()
	decal.name = "Splatter"
	var span := 1.05+0.25*float(posmod(serial,5))/4.0
	decal.size = Vector3(span,1.2,span)
	decal.texture_albedo = maps[0]
	decal.texture_normal = maps[1]
	decal.texture_orm = maps[2]
	decal.albedo_mix = 1.0
	decal.normal_fade = 0.35
	decal.upper_fade = 0.15
	decal.lower_fade = 0.35
	decal.rotation.y = fposmod(float(serial)*0.618034,1.0)*TAU
	decal.position.y = 0.1
	root.add_child(decal)
	# Lands: the stain spreads from small to full over a quarter second.
	decal.scale = Vector3(0.35,1,0.35)
	root.ready.connect(func():
		var grow := root.create_tween()
		grow.tween_property(decal,"scale",Vector3.ONE,0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT))
	root.add_child(_spray(serial))
	return root

# A one-shot burst of dark drops flung up and out, falling back.
static func _spray(serial: int) -> GPUParticles3D:
	var drops := GPUParticles3D.new()
	drops.name = "Spray"
	drops.amount = 22
	drops.lifetime = 0.7
	drops.one_shot = true
	drops.explosiveness = 0.95
	drops.randomness = 0.4
	drops.position = Vector3(0,0.9,0)
	drops.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0,0.4,0)
	process.spread = 75.0
	process.initial_velocity_min = 1.2
	process.initial_velocity_max = 2.6
	process.gravity = Vector3(0,-9.8,0)
	process.scale_min = 0.4
	process.scale_max = 1.0
	var fade := Gradient.new()
	fade.set_color(0,Color(0.42,0.03,0.03,1.0))
	fade.set_color(1,Color(0.3,0.02,0.02,0.0))
	var ramp := GradientTexture1D.new(); ramp.gradient = fade
	process.color_ramp = ramp
	drops.process_material = process
	var quad := QuadMesh.new(); quad.size = Vector2(0.05,0.05)
	var look := StandardMaterial3D.new()
	look.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.vertex_color_use_as_albedo = true
	look.roughness = 0.2
	look.albedo_texture = preload("res://Presentation/ShipMotion.gd").soft_dot()
	quad.material = look
	drops.draw_pass_1 = quad
	drops.finished.connect(drops.queue_free)
	drops.emitting = true
	return drops

# [albedo, normal, orm] for one splatter variant, generated once.
static func _maps(variant: int) -> Array:
	if textures.has(variant): return textures[variant]
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 9173+variant*131
	var noise := FastNoiseLite.new()
	noise.seed = variant*17+3
	noise.frequency = 0.018
	noise.fractal_octaves = 4
	# Height field 0..1: pooled centre, satellites, streaks.
	var height := PackedFloat32Array()
	height.resize(SIZE*SIZE)
	var blobs: Array = []
	var pool := 0.2+rnd.randf()*0.06
	blobs.append([Vector2(0.5,0.5)+Vector2(rnd.randf_range(-0.03,0.03),rnd.randf_range(-0.03,0.03)),pool,Vector2.ZERO])
	for i in 3:
		var a := rnd.randf()*TAU
		blobs.append([Vector2(0.5,0.5)+Vector2(cos(a),sin(a))*pool*0.6,pool*rnd.randf_range(0.35,0.55),Vector2.ZERO])
	for i in rnd.randi_range(14,24):
		var a := rnd.randf()*TAU
		var d := rnd.randf_range(pool+0.04,0.46)
		blobs.append([Vector2(0.5,0.5)+Vector2(cos(a),sin(a))*d,rnd.randf_range(0.008,0.03),Vector2.ZERO])
	for i in rnd.randi_range(4,7):
		var a := rnd.randf()*TAU
		var d := rnd.randf_range(pool*0.8,pool+0.12)
		blobs.append([Vector2(0.5,0.5)+Vector2(cos(a),sin(a))*d,rnd.randf_range(0.02,0.035),Vector2(cos(a),sin(a))*rnd.randf_range(0.05,0.12)])
	# Each blob only touches the pixels inside its own bounds.
	for b in blobs:
		var c: Vector2 = b[0]
		var radius: float = b[1]
		var streak: Vector2 = b[2]
		var reach := radius*1.15+streak.length()+0.02
		var x0 := maxi(0,int((c.x-reach)*SIZE))
		var x1 := mini(SIZE-1,int((c.x+reach)*SIZE)+1)
		var y0 := maxi(0,int((c.y-reach)*SIZE))
		var y1 := mini(SIZE-1,int((c.y+reach)*SIZE)+1)
		var dir := streak.normalized() if streak != Vector2.ZERO else Vector2.ZERO
		for y in range(y0,y1+1):
			for x in range(x0,x1+1):
				var q := Vector2((x+0.5)/SIZE,(y+0.5)/SIZE)-c
				var r := radius
				if streak != Vector2.ZERO:
					# Elongated along its flung direction, tapering.
					var along := q.dot(dir)
					var t := clampf(along/streak.length(),0.0,1.0)
					q -= dir*clampf(along,0.0,streak.length())
					r *= 1.0-0.7*t
				var dist := q.length()-(r+noise.get_noise_2d(x,y)*0.06*(r/pool))
				var h := clampf(1.0-dist/0.012,0.0,1.0) if dist > 0.0 else 1.0
				if h > height[y*SIZE+x]: height[y*SIZE+x] = h
	var albedo := Image.create(SIZE,SIZE,false,Image.FORMAT_RGBA8)
	var normal := Image.create(SIZE,SIZE,false,Image.FORMAT_RGBA8)
	var orm := Image.create(SIZE,SIZE,false,Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var h: float = height[y*SIZE+x]
			var p := Vector2((x+0.5)/SIZE,(y+0.5)/SIZE)
			var centre := clampf(1.0-p.distance_to(Vector2(0.5,0.5))/0.3,0.0,1.0)
			var grain := noise.get_noise_2d(x*3.0,y*3.0)*0.5+0.5
			# Thick pooled blood is near black-red; thin edges and drops brighter.
			var deep := Color(0.12,0.008,0.008)
			var thin := Color(0.34,0.025,0.022)
			var c := thin.lerp(deep,clampf(centre*1.2+grain*0.25,0.0,1.0))
			albedo.set_pixel(x,y,Color(c.r,c.g,c.b,clampf(h*1.15,0.0,1.0)))
			# Wet rim: the height slope gives the meniscus its highlight.
			var hx: float = height[y*SIZE+mini(x+1,SIZE-1)]-height[y*SIZE+maxi(x-1,0)]
			var hy: float = height[mini(y+1,SIZE-1)*SIZE+x]-height[maxi(y-1,0)*SIZE+x]
			var n := Vector3(-hx*3.0,-hy*3.0,1.0).normalized()
			normal.set_pixel(x,y,Color(n.x*0.5+0.5,n.y*0.5+0.5,n.z*0.5+0.5,1.0))
			orm.set_pixel(x,y,Color(1.0,0.08+0.12*(1.0-h),0.0,1.0))
	albedo.generate_mipmaps()
	normal.generate_mipmaps()
	orm.generate_mipmaps()
	textures[variant] = [ImageTexture.create_from_image(albedo),ImageTexture.create_from_image(normal),ImageTexture.create_from_image(orm)]
	return textures[variant]
