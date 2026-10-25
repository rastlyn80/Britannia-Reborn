extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--reference="): path = arg.substr(12)
	var tiles: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
	var world: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://play-world.json"))
	root.size = Vector2i(1600,1600)
	for sheet in 3:
		for node in root.get_children(): node.queue_free()
		await process_frame
		for index in range(sheet*64,mini((sheet+1)*64,tiles.size())):
			var tile: Dictionary = tiles[index]
			var cell := Vector2((index%64)%8,(index%64)/8)*200
			var image := Image.create_from_data(tile.width,tile.height,false,Image.FORMAT_RGBA8,Marshalls.base64_to_raw(tile.rgba))
			var sprite := Sprite2D.new()
			sprite.texture = ImageTexture.create_from_image(image)
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var factor := minf(1.5,minf(170.0/tile.width,155.0/tile.height))
			sprite.scale = Vector2.ONE*factor
			sprite.position = cell+Vector2(100,95)
			root.add_child(sprite)
			var label := Label.new()
			label.text = "0x%04X %s" % [tile.id,world.staticData[str(int(tile.id))].name]
			label.position = cell+Vector2(8,174)
			label.add_theme_font_size_override("font_size",14)
			root.add_child(label)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(path.get_base_dir().path_join("static-reference-%d.png" % sheet))
	quit()
