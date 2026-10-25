extends SceneTree

var world: Dictionary
var palette: PackedByteArray
var hues: PackedByteArray

func color16(value: int) -> Color:
	return Color(float((value>>10)&31)/31.0,float((value>>5)&31)/31.0,float(value&31)/31.0)

func radar(index: int) -> Color:
	assert(index >= 0 and index*2+2 <= palette.size(),"Radar colour index outside source palette")
	return color16(palette.decode_u16(index*2))

func static_color(s: Dictionary) -> Color:
	if int(s.hue) > 0:
		var hue := (int(s.hue)&0x3fff)-1
		# hues.mul: 4-byte group header, eight 88-byte entries; radar uses shade 16.
		var offset := (hue/8)*708+4+(hue%8)*88+16*2
		if offset+2 <= hues.size(): return color16(hues.decode_u16(offset))
	return radar(int(s.id)+0x4000)

func drawable(s: Dictionary) -> bool:
	var id := int(s.id)
	if id in [0,1,0xffff,0x21bc,0xa1fe,0xa1ff,0xa200,0xa201,0x63d3]: return false
	if id >= 0x2198 and id <= 0x21a4: return false
	var data: Dictionary = world.staticData.get(str(id),{})
	if str(data.get("name","")).to_lower().begins_with("nodraw"): return false
	return (int(data.get("flags",0)) & 0x02000000) == 0

func label_at(text: String, position: Vector2, size: int = 20) -> void:
	var label := Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size",size)
	root.add_child(label)

func picture(image: Image, position: Vector2, size: Vector2) -> void:
	var texture := Sprite2D.new()
	texture.texture = ImageTexture.create_from_image(image)
	texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture.centered = false
	texture.position = position
	texture.scale = size/Vector2(image.get_size())
	root.add_child(texture)

func _initialize() -> void:
	call_deferred("render")

func render() -> void:
	var data_dir := ""
	var output := ""
	var overview := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--data="): data_dir = arg.substr(7)
		if arg.begins_with("--output="): output = arg.substr(9)
		if arg.begins_with("--overview="): overview = arg.substr(11)
	assert(not data_dir.is_empty() and not output.is_empty() and not overview.is_empty())
	world = JSON.parse_string(FileAccess.get_file_as_string("res://play-world.json"))
	palette = FileAccess.get_file_as_bytes(data_dir.path_join("radarcol.mul"))
	hues = FileAccess.get_file_as_bytes(data_dir.path_join("hues.mul"))
	assert(world.width == 64 and world.height == 64 and palette.size() > 0)
	var land := Image.create(64,64,false,Image.FORMAT_RGB8)
	var combined := Image.create(64,64,false,Image.FORMAT_RGB8)
	var elevations := {}
	for tile in world.terrain:
		var cell := Vector2i(int(tile.x)-int(world.originX),int(tile.y)-int(world.originY))
		land.set_pixelv(cell,radar(int(tile.id)))
		elevations[cell] = int(tile.z)
	combined.copy_from(land)
	var highest := {}
	for s in world.statics:
		if not drawable(s): continue
		var cell := Vector2i(int(s.x)-int(world.originX),int(s.y)-int(world.originY))
		if not highest.has(cell) or int(s.z) > int(highest[cell].z): highest[cell] = s
	for cell in highest:
		var s: Dictionary = highest[cell]
		if int(s.z) >= int(elevations[cell]): combined.set_pixelv(cell,static_color(s))
	assert(land.save_png(output.path_join("britain-terrain-64.png")) == OK)
	assert(combined.save_png(output.path_join("britain-radar-64.png")) == OK)
	var enlarged := combined.duplicate()
	enlarged.resize(1024,1024,Image.INTERPOLATE_NEAREST)
	assert(enlarged.save_png(output.path_join("britain-radar.png")) == OK)
	root.size = Vector2i(1800,820)
	label_at("BRITAIN / TRAMMEL — ORIGINAL MAP DATA VS 3D RECONSTRUCTION",Vector2(32,20),28)
	label_at("Exact same 64 × 64 crop: X 1576–1639 / Y 1568–1631. All three panels face north ↑; east →.",Vector2(32,64))
	picture(land,Vector2(32,152),Vector2(552,552))
	picture(combined,Vector2(624,152),Vector2(552,552))
	var rendered := Image.load_from_file(overview)
	var square := rendered.get_region(Rect2i((rendered.get_width()-rendered.get_height())/2,0,rendered.get_height(),rendered.get_height()))
	picture(square,Vector2(1216,152),Vector2(552,552))
	label_at("1  ORIGINAL TERRAIN",Vector2(32,112),24)
	label_at("2  ORIGINAL RADAR COLOURS + STATICS",Vector2(624,112),24)
	label_at("3  CURRENT 3D / TOP VIEW",Vector2(1216,112),24)
	label_at("Map land tiles only; no buildings or trees.",Vector2(32,718),18)
	label_at("Highest visible static base Z per cell, including roofs.\nLocal radarcol.mul + hues.mul; enlarged without smoothing.",Vector2(624,718),18)
	label_at("Quaternius replacements and procedural ground.\nGold markers are unresolved pieces.",Vector2(1216,718),18)
	label_at("Local map1LegacyMUL.uop + statics/diffs. Static data view; no live mobiles, multis or original client UI.",Vector2(32,788),17)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join("britain-map-comparison.png")) == OK)
	print("RADAR PASS: 4096 original terrain cells; original palette and static overlay; aligned 3D comparison")
	quit()
