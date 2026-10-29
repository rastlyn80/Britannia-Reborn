extends Node
# 3D item icons: each item graphic is built with the world's own model
# (WorldItems.studio_model), lit in a small studio and photographed once
# into a texture for the backpack, containers and quickbar. Items with only
# the generic fallback shape keep their classic art (icon() returns null and
# `fallback` lists them). One icon is rendered per frame; results are cached
# for the session.
signal icon_ready(graphic: int, hue: int, texture: Texture2D)
const SIZE := 192
static var instance: Node
var world_items: Node3D
var viewport := SubViewport.new()
var stage := Node3D.new()
var camera := Camera3D.new()
var icons := {}
var fallback := {}
var queue: Array = []
var busy := false

static func key(graphic: int, hue: int) -> String: return "%d:%d" % [graphic,hue]

func configure(items: Node3D) -> void:
	world_items = items
	instance = self

func _ready() -> void:
	viewport.size = Vector2i(SIZE,SIZE)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	studio_lights(viewport)
	viewport.add_child(stage)
	camera.fov = 28
	viewport.add_child(camera)
	camera.current = true

func _exit_tree() -> void:
	if instance == self: instance = null

# Soft three-point light and a neutral environment, shared with the inspect view.
static func studio_lights(parent: Node) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72,0.7,0.68)
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var holder := WorldEnvironment.new()
	holder.environment = environment
	parent.add_child(holder)
	for light in [[Vector3(-40,-35,0),Color(1.0,0.93,0.82),1.5],[Vector3(-20,140,0),Color(0.7,0.8,1.0),0.55],[Vector3(25,180,0),Color(1,1,1),0.9]]:
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = light[0]
		sun.light_color = light[1]
		sun.light_energy = light[2]
		parent.add_child(sun)

# The icon for an item graphic, or null while it renders (icon_ready follows)
# or when it has no model of its own (then the caller keeps classic art).
func icon(graphic: int, hue := 0) -> Texture2D:
	var k := key(graphic,hue)
	if icons.has(k): return icons[k]
	if fallback.has(k) or world_items == null: return null
	if not k in queue: queue.append(k)
	return null

static func lookup(graphic: int, hue := 0) -> Texture2D:
	return instance.icon(graphic,hue) if instance else null

# Bounds of every mesh under a node: world space once it is in a scene (the
# cameras frame in world space), the node's own space before that.
static func bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mesh in root.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh == null or not mesh.visible: continue
		var local: Transform3D = mesh.global_transform if root.is_inside_tree() else _relative(root,mesh)
		var part: AABB = local*mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	return box

static func _relative(root: Node3D, node: Node3D) -> Transform3D:
	var transform := Transform3D.IDENTITY
	var current: Node = node
	while current and current != root:
		if current is Node3D: transform = current.transform*transform
		current = current.get_parent()
	return transform

# Three-quarter view that fits the whole model.
# The fit uses the narrower of the two view angles (aspect = width/height).
static func frame(target: Camera3D, box: AABB, yaw := 0.6, pitch := -0.45, margin := 1.05, aspect := 1.0) -> void:
	var radius := maxf(box.size.length()*0.5,0.05)
	var half := deg_to_rad(target.fov*0.5)
	if aspect < 1.0: half = atan(tan(half)*aspect)
	var distance := radius/sin(half)*margin
	var direction := Vector3(sin(yaw)*cos(pitch),-sin(pitch),cos(yaw)*cos(pitch))
	target.position = box.get_center()+direction*distance
	target.near = maxf(0.01,distance-radius*2.0)
	target.far = distance+radius*2.0
	target.look_at(box.get_center())

func _process(_delta: float) -> void:
	if busy or queue.is_empty() or world_items == null: return
	_render(queue.pop_front())

func _render(k: String) -> void:
	busy = true
	var parts := k.split(":")
	var model: Node3D = world_items.studio_model(int(parts[0]),int(parts[1]))
	if model == null or str(model.get_meta("studio_quality","")) != "model":
		fallback[k] = true
		if model: model.free()
		busy = false
		return
	stage.add_child(model)
	# Icons fill their tile: a tighter fit than the inspect view.
	frame(camera,bounds(model),0.6,-0.45,0.8)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	model.queue_free()
	if image and not image.is_empty():
		image.generate_mipmaps()
		icons[k] = ImageTexture.create_from_image(image)
		icon_ready.emit(int(parts[0]),int(parts[1]),icons[k])
	busy = false
