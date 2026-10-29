extends "res://Network/ModernWindow.gd"
# The house designer (custom houses): opens when the server starts
# customisation (0xBF 0x20) and closes when it ends. The palette is the
# install's designer catalogue (walls, doors, floors, stairs, roofs, misc,
# teleporters; scripts/prepare-multis.py), each piece photographed in 3D with
# the same rules that build the house. In the world, the cell under the mouse
# on the current floor is outlined: left-click builds the chosen piece,
# right-click (or the Erase tool) removes the top piece there. Every change is
# a 0xD7 designer command; the server answers with a new revision and the
# design (0xD8), which the house presenter rebuilds.
const Multis = preload("res://Presentation/MultiPresenter.gd")
const WorldSystems = preload("res://Network/Packets/WorldSystems.gd")
const Studio = preload("res://Presentation/ItemStudio.gd")
const CATEGORIES := [["walls","Walls"],["doors","Doors"],["floors","Floors"],["stairs","Stairs"],["roof","Roofs"],["misc","Misc"],["teleprts","Teleporters"]]
const SKIP := ["Category","Style","TID","FeatureMask","Comment"]
var scene: Node3D
var game: Node
var systems: RefCounted
var house := 0
var floor_level := 1
var category := "walls"
var style := 0
var piece := 0
var piece_command := 0x06
var erasing := false
var styles := ItemList.new()
var pieces := GridContainer.new()
var status: Label
var floor_buttons: Array = []
var erase_button: Button
var cursor := MeshInstance3D.new()
var cell := Vector2i(-9999,-9999)

func _ready() -> void:
	setup("designer","House designer",Vector2(640,600),Vector2(20,110))
	var floors := HBoxContainer.new()
	floors.add_theme_constant_override("separation",6)
	body.add_child(floors)
	floors.add_child(Look.label("Floor",13,Look.ASH,600))
	for level in range(1,5):
		var button := Button.new()
		button.text = str(level)
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(34,30)
		button.pressed.connect(func(): _floor(level))
		floors.add_child(button)
		floor_buttons.append(button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	floors.add_child(spacer)
	erase_button = Button.new()
	erase_button.text = "Erase"
	erase_button.toggle_mode = true
	erase_button.toggled.connect(func(on: bool):
		erasing = on
		_status())
	floors.add_child(erase_button)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation",4)
	body.add_child(tabs)
	for entry in CATEGORIES:
		var tab := Button.new()
		tab.text = entry[1]
		tab.pressed.connect(func():
			category = entry[0]
			style = 0
			_fill_styles())
		tabs.add_child(tab)
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation",10)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(split)
	styles.custom_minimum_size = Vector2(220,0)
	styles.item_selected.connect(func(index: int):
		style = index
		_fill_pieces())
	split.add_child(styles)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(scroll)
	pieces.columns = 4
	pieces.add_theme_constant_override("h_separation",6)
	pieces.add_theme_constant_override("v_separation",6)
	scroll.add_child(pieces)
	status = Look.label("",12,Look.ASH,500)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(status)
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("separation",4)
	body.add_child(actions)
	for entry in [["Backup",0x02],["Restore",0x03],["Sync",0x0e],["Revert",0x1a],["Clear",0x10],["Commit",0x04],["Close",0x0c]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(func():
			_command(int(entry[1]))
			if int(entry[1]) in [0x03,0x10,0x1a]: _command(0x0e))
		actions.add_child(button)

func configure(world_scene: Node3D) -> void:
	scene = world_scene
	game = scene.game
	systems = game.module("world")
	systems.customizing.connect(func(serial: int, active: bool):
		if active: open(serial)
		elif serial == house: close())
	game.ended.connect(close)
	if Studio.instance: Studio.instance.icon_ready.connect(func(_g: int, hue: int, _t: Texture2D): if visible and hue == -1: _refresh_icons())
	var outline := StandardMaterial3D.new()
	outline.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline.albedo_color = Color(Look.GOLD,0.45)
	var quad := BoxMesh.new()
	quad.size = Vector3(1,0.04,1)
	cursor.mesh = quad
	cursor.material_override = outline
	cursor.visible = false
	scene.add_child(cursor)

func open(serial: int) -> void:
	house = serial
	_floor(1)
	_fill_styles()
	show()
	move_to_front()

func close() -> void:
	house = 0
	cursor.visible = false
	hide()

func _floor(level: int) -> void:
	floor_level = level
	for i in floor_buttons.size(): floor_buttons[i].set_pressed_no_signal(i+1 == level)
	if house: game.send(WorldSystems.designer_level(int(game.player.serial),level))
	_status()

func _command(command: int) -> void:
	if house: game.send(WorldSystems.designer(int(game.player.serial),command))

func _catalogue() -> Array:
	return Multis.index().get("designer",{}).get(category,[])

func _fill_styles() -> void:
	styles.clear()
	for row in _catalogue(): styles.add_item(str(row.get("Comment","Style")))
	if styles.item_count > 0:
		styles.select(clampi(style,0,styles.item_count-1))
	_fill_pieces()

func _fill_pieces() -> void:
	clear(pieces)
	var rows := _catalogue()
	if style >= rows.size(): return
	var row: Dictionary = rows[style]
	for column in row:
		if column in SKIP or not row[column] is float and not row[column] is int: continue
		var graphic := int(row[column])
		if graphic <= 0: continue
		# Stairs' Multi* columns are whole stair multis (designer command 0x0D).
		var command := 0x0d if category == "stairs" and str(column).begins_with("Multi") else (0x13 if category == "roof" else 0x06)
		var button := Button.new()
		button.custom_minimum_size = Vector2(76,76)
		button.toggle_mode = true
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.tooltip_text = "%s (%d)" % [column,graphic]
		button.set_meta("graphic",graphic)
		button.set_meta("command",command)
		button.icon = Studio.tile_lookup(graphic) if command != 0x0d else null
		if command == 0x0d: button.text = str(column).trim_prefix("Multi")
		button.button_pressed = graphic == piece
		button.pressed.connect(func():
			piece = graphic
			piece_command = command
			erasing = false
			erase_button.set_pressed_no_signal(false)
			for other in pieces.get_children(): other.set_pressed_no_signal(other == button)
			_status())
		pieces.add_child(button)

func _refresh_icons() -> void:
	for button in pieces.get_children():
		if button.icon == null and int(button.get_meta("command",0)) != 0x0d: button.icon = Studio.tile_lookup(int(button.get_meta("graphic",0)))

func _status() -> void:
	if erasing: status.text = "Floor %d · Erase: click a piece in the house to remove it." % floor_level
	elif piece: status.text = "Floor %d · Click inside the house to place piece %d; right-click removes." % [floor_level,piece]
	else: status.text = "Floor %d · Choose a piece, then click inside the house." % floor_level

# Height of the current floor's walking surface (ClassicUO: 7 + 20 per floor).
func floor_z() -> int:
	return int(game.multis.get(house,{}).get("z",0))+7+(floor_level-1)*20

func _process(_delta: float) -> void:
	if not visible or house == 0 or not game.multis.has(house):
		cursor.visible = false
		return
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered != null:
		cursor.visible = false
		return
	var camera: Camera3D = scene.camera
	var mouse := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse)
	var toward := camera.project_ray_normal(mouse)
	var height := floor_z()*float(scene.world.elevationScale)
	if absf(toward.y) < 0.001: return
	var at := from+toward*((height-from.y)/toward.y)
	cell = Vector2i(floori(at.x)+int(scene.world.originX),floori(at.z)+int(scene.world.originY))
	var multi: Dictionary = game.multis[house]
	var box := Multis.bounds(int(multi.id))
	var inside := Rect2i(box.position,box.size+Vector2i.ONE).has_point(cell-Vector2i(int(multi.x),int(multi.y)))
	cursor.visible = inside
	cursor.position = scene.point(cell.x,cell.y,floor_z())+Vector3(0.5,0.03,0.5)

func _unhandled_input(event: InputEvent) -> void:
	if not visible or house == 0 or not cursor.visible or not event is InputEventMouseButton or not event.pressed: return
	if event.button_index == MOUSE_BUTTON_LEFT and not erasing and piece:
		get_viewport().set_input_as_handled()
		_build()
	elif event.button_index == MOUSE_BUTTON_RIGHT or (event.button_index == MOUSE_BUTTON_LEFT and erasing):
		get_viewport().set_input_as_handled()
		_erase()

func _relative() -> Vector2i:
	var multi: Dictionary = game.multis[house]
	return cell-Vector2i(int(multi.x),int(multi.y))

func _build() -> void:
	var at := _relative()
	game.send(WorldSystems.designer_tile(int(game.player.serial),piece_command,piece,at.x,at.y,0))
	# ModernUO only bumps the revision; Sync returns the design as it now is.
	_command(0x0e)

# Removes the top piece at the cell on this floor (from the design the server sent).
func _erase() -> void:
	var at := _relative()
	var multi: Dictionary = game.multis[house]
	var low := floor_z()-int(multi.z)-7
	var best: Array = []
	for part in Multis.design_parts(systems.designs.get(house,{}),int(multi.id)):
		if int(part[1]) != at.x or int(part[2]) != at.y: continue
		if int(part[3]) < low or int(part[3]) >= low+27: continue
		if best.is_empty() or int(part[3]) >= int(best[3]): best = part
	if best.is_empty(): return
	var roof: bool = int(Multis.tile(int(best[0])).get("flags",0)) & 0x10000000 != 0
	game.send(WorldSystems.designer_tile(int(game.player.serial),0x14 if roof else 0x05,int(best[0]),at.x,at.y,int(best[3])))
	_command(0x0e)
