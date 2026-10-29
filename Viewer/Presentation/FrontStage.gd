extends Node3D
# The front end's own small world: a moonlit night with a castle silhouette on
# a hill, a moongate and a stone plinth where the chosen character stands. It
# loads nothing from the map, so signing in costs a fraction of a district.
# Two camera framings: "vista" (sign in, loading) and "stage" (characters).
const Avatar = preload("res://Presentation/Avatar.gd")
var camera := Camera3D.new()
var avatar: Node3D
var facing := 0.0
var framing := "vista"
var clock := 0.0
# The vista stands past the plinth, so the empty stage is behind the camera.
const VISTA := [Vector3(1.5,1.9,-1.8),Vector3(-3.0,3.8,-40.0)]
const STAGE := [Vector3(0.0,1.55,4.3),Vector3(0.0,1.05,0.0)]

func _ready() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	var sky := ShaderMaterial.new()
	sky.shader = preload("res://Presentation/FrontSky.gdshader")
	environment.sky.sky_material = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.32,0.36,0.5)
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.2,0.23,0.32)
	environment.fog_density = 0.012
	environment.fog_sky_affect = 0.15
	environment.glow_enabled = true
	environment.glow_intensity = 0.6
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.72,0.78,1.0)
	moon.light_energy = 0.55
	moon.shadow_enabled = true
	moon.rotation_degrees = Vector3(-24,-152,0)
	add_child(moon)
	_ground()
	_castle(Vector3(-14,0,-95))
	_trees()
	_moongate(Vector3(7.5,0,-17.0))
	_plinth()
	add_child(camera)
	camera.fov = 50
	camera.far = 600
	_place(VISTA)

func _material(color: Color, roughness := 0.95) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _box(size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.mesh.size = size
	mesh.position = at
	mesh.material_override = material
	add_child(mesh)
	return mesh

func _ground() -> void:
	var ground := MeshInstance3D.new()
	ground.mesh = PlaneMesh.new()
	ground.mesh.size = Vector2(600,600)
	ground.material_override = _material(Color(0.07,0.09,0.08))
	add_child(ground)
	# The castle's hill: a wide, low mound in the fog.
	var hill := MeshInstance3D.new()
	hill.mesh = SphereMesh.new()
	hill.mesh.radius = 60
	hill.mesh.height = 24
	hill.position = Vector3(-14,-4,-100)
	hill.material_override = _material(Color(0.05,0.065,0.07))
	add_child(hill)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	floor_body.add_child(shape)
	add_child(floor_body)

# Keep, towers and curtain walls with battlements, dark against the moonlit
# sky, with a few warm windows.
func _castle(base: Vector3) -> void:
	var stone := _material(Color(0.06,0.065,0.08))
	var lit := StandardMaterial3D.new()
	lit.albedo_color = Color(1.0,0.72,0.38)
	lit.emission_enabled = true
	lit.emission = Color(1.0,0.66,0.3)
	lit.emission_energy_multiplier = 3.0
	var top := base+Vector3(0,7.5,0)
	_box(Vector3(34,9,6),top+Vector3(0,4.5,6),stone)
	for x in range(-16,17,4): _box(Vector3(2,1.4,6.2),top+Vector3(x,9.7,6),stone)
	_box(Vector3(12,18,12),top+Vector3(0,9,-4),stone)
	for x in [-5,-1,3]: _box(Vector3(2,1.6,12.4),top+Vector3(x,18.8,-4),stone)
	for side in [-1,1]:
		_box(Vector3(7,15,7),top+Vector3(side*18,7.5,5),stone)
		for x in [-2.5,2.5]: _box(Vector3(1.8,1.4,7.2),top+Vector3(side*18+x,15.7,5),stone)
	for at in [Vector3(-2,12,2.1),Vector3(2.5,12,2.1),Vector3(0,7,2.1),Vector3(-18,9,8.6),Vector3(18,10,8.6)]:
		_box(Vector3(0.9,1.4,0.1),top+at,lit)
	var glow := OmniLight3D.new()
	glow.position = top+Vector3(0,9,6)
	glow.light_color = Color(1.0,0.7,0.4)
	glow.omni_range = 22
	glow.light_energy = 0.8
	add_child(glow)

func _trees() -> void:
	var places := [[Vector3(-7,0,-6),"CommonTree_2",7.0],[Vector3(-11,0,-14),"CommonTree_4",8.5],[Vector3(10,0,-16),"CommonTree_1",7.5],[Vector3(-4,0,-22),"DeadTree_2",6.0],[Vector3(15,0,-6),"CommonTree_5",8.0],[Vector3(-16,0,-3),"CommonTree_3",7.0]]
	for entry in places:
		var path := "res://Art/Quaternius/Nature/%s.gltf" % entry[1]
		if not ResourceLoader.exists(path): continue
		var tree: Node3D = load(path).instantiate()
		var bounds := AABB()
		for mesh in tree.find_children("*","MeshInstance3D",true,false): bounds = bounds.merge(mesh.get_aabb()) if bounds.size != Vector3.ZERO else mesh.get_aabb()
		tree.scale = Vector3.ONE*(float(entry[2])/maxf(bounds.size.y,0.1))
		tree.position = entry[0]
		tree.rotation.y = entry[0].x*0.37
		add_child(tree)

func _moongate(at: Vector3) -> void:
	var gate := MeshInstance3D.new()
	gate.mesh = QuadMesh.new()
	gate.mesh.size = Vector2(2.4,3.8)
	gate.position = at+Vector3(0,2.0,0)
	gate.rotation.y = -0.35
	var material := ShaderMaterial.new()
	material.shader = preload("res://Presentation/Moongate.gdshader")
	gate.material_override = material
	add_child(gate)
	var light := OmniLight3D.new()
	light.position = at+Vector3(0,1.8,0.8)
	light.light_color = Color(0.4,0.6,1.0)
	light.light_energy = 2.2
	light.omni_range = 9
	add_child(light)

func _plinth() -> void:
	var stone := _material(Color(0.24,0.23,0.22),0.85)
	var base := MeshInstance3D.new()
	base.mesh = CylinderMesh.new()
	base.mesh.top_radius = 1.05
	base.mesh.bottom_radius = 1.2
	base.mesh.height = 0.3
	base.position.y = 0.15
	base.material_override = stone
	add_child(base)
	var trim := MeshInstance3D.new()
	trim.mesh = TorusMesh.new()
	trim.mesh.inner_radius = 1.02
	trim.mesh.outer_radius = 1.08
	trim.position.y = 0.3
	var brass := _material(Color(0.84,0.7,0.43),0.4)
	brass.metallic = 0.8
	trim.material_override = brass
	add_child(trim)
	var top := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = CylinderShape3D.new()
	shape.shape.radius = 1.05
	shape.shape.height = 0.3
	shape.position.y = 0.15
	top.add_child(shape)
	add_child(top)
	var key := SpotLight3D.new()
	key.position = Vector3(1.6,4.2,3.0)
	key.light_color = Color(1.0,0.86,0.66)
	key.light_energy = 6.0
	key.spot_range = 9
	key.spot_angle = 26
	key.shadow_enabled = true
	add_child(key)
	key.look_at_from_position(key.position,Vector3(0,1.0,0))
	var rim := OmniLight3D.new()
	rim.position = Vector3(-1.4,2.2,-1.6)
	rim.light_color = Color(0.45,0.6,1.0)
	rim.light_energy = 1.4
	rim.omni_range = 5
	add_child(rim)

func _place(pair: Array) -> void:
	camera.position = pair[0]
	camera.look_at(pair[1])

func frame(mode: String) -> void:
	framing = mode

# Show a character on the plinth: entity {body, hue, flags} and worn items
# ({id, hue, layer}); an empty entity clears the plinth.
func show_character(entity: Dictionary, worn: Array) -> void:
	if entity.is_empty():
		if avatar: avatar.queue_free()
		avatar = null
		return
	var body := int(entity.get("body",400))
	if avatar == null or int(avatar.initial_body) != body:
		if avatar: avatar.queue_free()
		avatar = Avatar.new()
		avatar.initial_body = body
		avatar.position = Vector3(0,0.3,0)
		add_child(avatar)
	avatar.apply_server_appearance(entity,worn)

func turn(amount: float) -> void:
	facing += amount

func _process(delta: float) -> void:
	clock += delta
	var pair: Array = STAGE if framing == "stage" else VISTA
	var drift := Vector3(sin(clock*0.11)*0.35,sin(clock*0.07)*0.12,0) if framing == "vista" else Vector3(sin(clock*0.2)*0.05,0,0)
	var goal := Transform3D(Basis.IDENTITY,pair[0]+drift).looking_at(pair[1])
	camera.global_transform = camera.global_transform.interpolate_with(goal,1.0-exp(-2.5*delta))
	if avatar and avatar.is_inside_tree() and avatar.has_method("animate"):
		avatar.animate(false,facing,delta)
