extends SceneTree
## Review the exact shared-skeleton renderer used by the playable client.
var actors: Array[Node3D] = []
var clip := "Idle"
var capture := ""
var outfit := "base"
var angle := 0.
var frames := 0
var camera: Camera3D
var hair_type := 0x203b
var hair_hue := 0
var beard_type := 0
var beard_hue := 0
var varied := false
var head_view := false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="): capture=arg.substr(13)
		if arg.begins_with("--outfit="): outfit=arg.substr(9)
		if arg.begins_with("--clip="): clip=arg.substr(7)
		if arg=="--profile": angle=PI/2
		if arg=="--rear": angle=PI
		if arg.begins_with("--hair-id="): hair_type=arg.substr(10).hex_to_int()
		if arg.begins_with("--hair-hue="): hair_hue=arg.substr(11).to_int()
		if arg.begins_with("--beard-id="): beard_type=arg.substr(11).hex_to_int()
		if arg.begins_with("--beard-hue="): beard_hue=arg.substr(12).to_int()
		if arg=="--varied": varied=true
		if arg=="--head": head_view=true
	call_deferred("build")

func wear(name: String, is_female: bool = false) -> Array:
	var items: Array = []
	if hair_type: items.append({"id":0x203c if varied and is_female else hair_type,"layer":11,"hue":1118 if varied and is_female else hair_hue})
	if beard_type and not is_female: items.append({"id":beard_type,"layer":16,"hue":beard_hue})
	var selected: Array = []
	match name:
		"viking": selected=[0x1fa1,0x1539,0x170b]
		"monk": selected=[0x2687]
		"robe": selected=[0x1f03]
		"tunic": selected=[0x1fa1]
		"pants": selected=[0x1539]
		"boots": selected=[0x170b]
		"hood": selected=[0x278f]
		"skirt": selected=[0x1516]
		"kilt": selected=[0x1fa1,0x1537,0x170b]
		"guard": selected=[0x1fa1,0x1539,0x170b,0x13c6,0x1412,0x0f5e]
		"sword": selected=[0x1fa1,0x1539,0x170b,0x0f5e]
		"hammer": selected=[0x1fa1,0x1539,0x170b,0x1439]
		"staff": selected=[0x1f03,0x0e81]
		"shirt": selected=[0x1517,0x1539,0x170b]
		"cap": selected=[0x1517,0x1539,0x170b,0x1715]
		"felt_hat": selected=[0x1517,0x1539,0x170b,0x1713]
		"doublet": selected=[0x1517,0x1f7b,0x1539,0x170f]
		"cloak": selected=[0x1517,0x1f7b,0x1539,0x170f,0x1515]
		"shoes": selected=[0x1517,0x1539,0x170f]
		"sandals": selected=[0x1517,0x1539,0x170d]
	for id in selected: items.append({"id":id,"layer":0,"hue":0})
	return items

func build() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("26333e")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("bdcbd5")
	env.environment.ambient_light_energy=.4
	env.environment.tonemap_mode=Environment.TONE_MAPPER_AGX
	stage.add_child(env)
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-48,-25,0)
	sun.light_energy=1.05
	sun.shadow_enabled=true
	stage.add_child(sun)
	var floor_node:=MeshInstance3D.new()
	var plane:=BoxMesh.new()
	plane.size=Vector3(12,.1,10)
	floor_node.mesh=plane
	floor_node.position.y=-.05
	var floor_mat:=StandardMaterial3D.new()
	floor_mat.albedo_color=Color("5b6264")
	floor_node.material_override=floor_mat
	stage.add_child(floor_node)
	for female in [false,true]:
		var actor:=preload("res://Presentation/HumanVisual.gd").new()
		actor.female=female
		actor.use_modern_motion=not "--baseline" in OS.get_cmdline_user_args()
		actor.position.x=(.24 if female else -.24) if head_view else (.8 if female else -.8)
		actor.rotation.y=angle
		stage.add_child(actor)
		actor.set_equipment(wear(outfit,female))
		actor.play(clip,0.)
		actors.append(actor)
	camera=Camera3D.new()
	camera.fov=40.
	stage.add_child(camera)
	camera.position=Vector3(0,1.65,4.5)
	camera.look_at(Vector3(0,.98,0))
	if head_view:
		camera.fov=28.
		camera.position=Vector3(0,1.67,1.7)
		camera.look_at(Vector3(0,1.62,0))
	var ui:=VBoxContainer.new()
	ui.position=Vector2(24,20)
	root.add_child(ui)
	var title:=Label.new()
	title.text="BRITANNIA REBORN / HUMAN FOUNDATION\nMale (left) / Female (right) • expanded wardrobe • game-driven hair and clothing colours"
	ui.add_child(title)
	var row:=HFlowContainer.new()
	row.custom_minimum_size.x=1120
	ui.add_child(row)
	for name in ["base","viking","monk","robe","tunic","pants","boots","hood","skirt","kilt","guard","sword","hammer","staff","shirt","cap","felt_hat","doublet","cloak","shoes","sandals"]:
		var b:=Button.new()
		b.text=name.capitalize()
		b.pressed.connect(func():
			outfit=name
			for actor in actors: actor.set_equipment(wear(name,actor.female)))
		row.add_child(b)
	var cosmetics:=HBoxContainer.new()
	ui.add_child(cosmetics)
	for entry in [["Bald",0],["Short",0x203b],["Long",0x203c],["Ponytail",0x203d],["Pageboy",0x2045],["Afro",0x2047]]:
		var b:=Button.new()
		b.text=str(entry[0])
		b.pressed.connect(func():
			hair_type=int(entry[1])
			for actor in actors: actor.set_equipment(wear(outfit,actor.female)))
		cosmetics.add_child(b)
	for entry in [["Clean shave",0],["Beard",0x203e],["Short beard",0x203f],["Goatee",0x2040],["Moustache",0x2041]]:
		var b:=Button.new()
		b.text=str(entry[0])
		b.pressed.connect(func():
			beard_type=int(entry[1])
			for actor in actors: actor.set_equipment(wear(outfit,actor.female)))
		cosmetics.add_child(b)
	var motion:=HBoxContainer.new()
	ui.add_child(motion)
	for name in ["Idle","Walk","Run"]:
		var b:=Button.new()
		b.text=name
		b.pressed.connect(func():
			for actor in actors: actor.play(name))
		motion.add_child(b)
	for name in ["Front","Profile","Rear"]:
		var b:=Button.new()
		b.text=name
		b.pressed.connect(func():
			for actor in actors: actor.rotation.y=0. if name=="Front" else (PI/2 if name=="Profile" else PI))
		motion.add_child(b)
	if not capture.is_empty():
		for actor in actors:
			actor.animator.seek(actor.animator.current_animation_length*.23,true)
			actor.animator.pause()
		for i in 15: await process_frame
		await RenderingServer.frame_post_draw
		quit(root.get_texture().get_image().save_png(capture))
