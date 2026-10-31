extends Control
# Dragging an item out of a window onto the world: the screen behind every
# window becomes a drop target only while an item is being dragged (so it
# never takes ordinary clicks). Dropped on a character: given to them (on
# yourself: into your backpack). On the ground within reach: there.
# Farther away: at your feet, as the classic client does.
var scene: Node3D
var game: Node

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func configure(world_scene: Node3D) -> void:
	scene = world_scene
	game = scene.game

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		var value: Variant = get_viewport().gui_get_drag_data()
		mouse_filter = Control.MOUSE_FILTER_STOP if value is Dictionary and value.has("item_serial") else Control.MOUSE_FILTER_IGNORE
	elif what == NOTIFICATION_DRAG_END:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

func _can_drop_data(_at: Vector2, value: Variant) -> bool:
	return game != null and game.phase == "world" and value is Dictionary and value.has("item_serial") and game.known_items.has(int(value.item_serial))

func _drop_data(at: Vector2, value: Variant) -> void:
	var item: Dictionary = game.known_items.get(int(value.item_serial),{})
	preload("res://Network/AmountPrompt.gd").ask(self,item,str(game.labels.item_name(int(item.get("id",0)))),func(amount: int): _place(at,value,amount))

func _place(at: Vector2, value: Variant, amount: int) -> void:
	var serial := int(value.item_serial)
	var camera: Camera3D = scene.camera
	var from := camera.project_ray_origin(at)
	var hit := scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,from+camera.project_ray_normal(at)*30.0,5))
	if not hit.is_empty() and hit.collider.has_meta("server_mobile"):
		var mobile := int(hit.collider.get_meta("server_mobile"))
		game.move_item(serial,int(game.backpack) if mobile == int(game.player.serial) else mobile,false,Vector3i(-999,-999,-999),[],amount)
		return
	if not hit.is_empty():
		var world: Dictionary = scene.world
		var cell := Vector3i(floori(hit.position.x+float(world.originX)),floori(hit.position.z+float(world.originY)),roundi(hit.position.y/float(world.elevationScale)))
		if maxi(absi(cell.x-int(game.player.x)),absi(cell.y-int(game.player.y))) <= 2 and absi(cell.z-int(game.player.z)) <= 16:
			game.move_item(serial,0,false,cell,[],amount)
			return
	game.move_item(serial,0,false,Vector3i(-999,-999,-999),[],amount)
