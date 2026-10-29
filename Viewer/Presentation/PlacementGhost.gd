extends Node3D
# House and boat placement (0x99): a translucent copy of the multi follows the
# tile under the mouse, standing on the ground there. Left-click places it
# (0x6C location answer; the server decides whether it fits), Esc cancels like
# any target cursor. The multi's offset is applied as ClassicUO does: the
# multi's centre goes to the tile minus the offset.
const WorldSystems = preload("res://Network/Packets/WorldSystems.gd")
const Look = preload("res://Network/ModernSkin.gd")
var scene: Node3D
var game: Node
var systems: RefCounted
var request := {}
var ghost: Node3D
var cell := Vector2i(-1,-1)
var cell_z := 0
var glass := StandardMaterial3D.new()
var note: Label

func configure(world_scene: Node3D, canvas: CanvasLayer) -> void:
	scene = world_scene
	game = scene.game
	systems = game.module("world")
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.albedo_color = Color(Look.GOLD,0.38)
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	note = Look.label("Left-click to place · Esc cancels",14,Look.IVORY,600)
	note.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	note.position.y = 120
	note.add_theme_constant_override("outline_size",6)
	note.add_theme_color_override("font_outline_color",Color(0,0,0,0.8))
	note.hide()
	canvas.add_child(note)
	systems.placement_requested.connect(start)
	game.target_changed.connect(func(active: bool): if not active: stop())
	game.ended.connect(stop)

func start(value: Dictionary) -> void:
	stop()
	request = value
	ghost = Node3D.new()
	ghost.name = "PlacementGhost"
	add_child(ghost)
	var origin := Vector3i(int(scene.world.originX),int(scene.world.originY),0)
	var Multis := preload("res://Presentation/MultiPresenter.gd")
	var parts: Array = Multis.components(int(value.multi))
	if Multis.Ships.handles(int(value.multi)):
		var box: Rect2i = Multis.bounds(int(value.multi))
		var ship: Node3D = Multis.Ships.build(int(value.multi),box)
		ship.position = Vector3(box.position.x+box.size.x/2.0+0.5,0,box.position.y+box.size.y/2.0+0.5)
		ghost.add_child(ship)
		parts = []
	for part in parts:
		scene.multis._know(int(part[0]))
		var node: Node3D = scene.reconstruction.build({"x":origin.x+int(part[1]),"y":origin.y+int(part[2]),"z":int(part[3]),"id":int(part[0]),"hue":0},scene.world,-1)
		if node == null:
			var box := MeshInstance3D.new()
			box.mesh = BoxMesh.new()
			box.mesh.size = Vector3(1,0.1,1)
			box.position = Vector3(int(part[1])+0.5,int(part[3])*float(scene.world.elevationScale),int(part[2])+0.5)
			node = box
		ghost.add_child(node)
	# Ghosts are seen, never touched.
	for body in ghost.find_children("*","CollisionObject3D",true,false): body.queue_free()
	for mesh in ghost.find_children("*","GeometryInstance3D",true,false):
		mesh.material_override = glass
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	note.text = "Left-click to place · Esc cancels" if not parts.is_empty() else "Click where it should go · Esc cancels"
	note.show()
	set_process(true)
	set_process_unhandled_input(true)

func stop() -> void:
	request = {}
	if ghost: ghost.queue_free()
	ghost = null
	if note: note.hide()
	set_process(false)
	set_process_unhandled_input(false)

func _ready() -> void:
	set_process(false)
	set_process_unhandled_input(false)

func _process(_delta: float) -> void:
	if ghost == null: return
	var mouse := get_viewport().get_mouse_position()
	var camera: Camera3D = scene.camera
	var from := camera.project_ray_origin(mouse)
	var toward := camera.project_ray_normal(mouse)
	var query := PhysicsRayQueryParameters3D.create(from,from+toward*80.0)
	query.collide_with_areas = false
	for body in ghost.find_children("*","CollisionObject3D",true,false): query.exclude.append(body.get_rid())
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var at: Vector3
	if hit.is_empty():
		# Nothing under the mouse: the plane at the player's height.
		var height := int(game.player.get("z",0))*float(scene.world.elevationScale)
		if absf(toward.y) < 0.001: return
		at = from+toward*((height-from.y)/toward.y)
	else: at = hit.position
	cell = Vector2i(floori(at.x)+int(scene.world.originX),floori(at.z)+int(scene.world.originY))
	var land: Dictionary = scene.movement_surface.land_height(cell) if scene.movement_surface else {}
	cell_z = int(land.z) if not land.is_empty() else roundi(at.y/float(scene.world.elevationScale))
	var offset: Vector3i = request.offset
	ghost.position = scene.point(cell.x-offset.x,cell.y-offset.y,cell_z-offset.z)

func _unhandled_input(event: InputEvent) -> void:
	if ghost == null or not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT: return
	get_viewport().set_input_as_handled()
	place(cell.x,cell.y,cell_z)

func place(x: int, y: int, z: int) -> void:
	if request.is_empty(): return
	# On water, aim at the water tile itself, as a click on it would.
	var graphic := 0
	if scene.movement_surface:
		for tile in scene.movement_surface.statics.get(Vector2i(x,y),[]):
			var data: Dictionary = scene.world.staticData.get(str(int(tile.id)),{})
			if int(data.get("flags",0)) & 0x80:
				graphic = int(tile.id)
				z = int(tile.z)
				break
	game.send(WorldSystems.place_multi(request,x,y,z,graphic))
	game.target_request.clear()
	game.target_changed.emit(false)
