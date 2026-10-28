extends SceneTree
const Game=preload("res://Network/GameSession.gd")
const Wire=preload("res://Network/LoginProtocol.gd")
const Avatar=preload("res://Presentation/HumanAvatar.gd")
const Hue=preload("res://Presentation/HumanHue.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok:print("PASS ",label)
	else:failures+=1;push_error(label)
func equipment(serial: int,id: int,layer: int,hue: int) -> PackedByteArray:
	var p:=PackedByteArray([0x2e]);p.append_array(Wire.uint_be(serial,4));p.append_array(Wire.uint_be(id,2));p.append_array(PackedByteArray([0,layer]));p.append_array(Wire.uint_be(9,4));p.append_array(Wire.uint_be(hue,2));return p
func piece(actor: Node3D,name: String) -> MeshInstance3D:
	for mesh: MeshInstance3D in actor.parts:
		if mesh.name.begins_with("Extra_"+name):return mesh
	return null
func run() -> void:
	for female in [false,true]:
		var tag:="female" if female else "male"
		var actor:=Avatar.new();actor.initial_body=401 if female else 400;root.add_child(actor)
		var visual: Node3D=actor.human_visual
		var rig: Skeleton3D=visual.skeleton
		for entry in [[0x1517,"shirt"],[0x1715,"cap"],[0x1713,"felt_hat"]]:
			visual.set_equipment([{"id":entry[0],"hue":1135}]);var mesh:=piece(visual,entry[1])
			check(mesh!=null and mesh.get_node(mesh.skeleton)==rig and visual.missing_art.is_empty(),tag+": new "+entry[1]+" uses the existing live rig")
			await process_frame
		var layered:=preload("res://Presentation/HumanWardrobe.gd").resolve([{"id":0x1517},{"id":0x1f7b},{"id":0x1f03}])
		check(not layered.pieces.has("shirt"),tag+": outer robe conceals civilian torso layers")
		var game:=Game.new();root.add_child(game);game.player.serial=7;game.entities[9]={"serial":9,"body":actor.initial_body,"hue":1002,"flags":0,"notoriety":1}
		game.feed(equipment(0x40000101,0x1517,5,33));game.feed(equipment(0x40000102,0x203d,11,1118))
		if not female:game.feed(equipment(0x40000103,0x204d,16,1102))
		var profile:=game.appearance_for(9);actor.apply_server_appearance(game.entities[9],profile.equipment,profile)
		actor.animate(true,0.,1./30.,2.44);visual.animator.seek(.2,true);visual.animator.pause()
		var shirt:=piece(visual,"shirt");var first:=shirt.get_surface_override_material(0) as ShaderMaterial
		var palette: Texture2D=first.get_shader_parameter("hue_palette")
		check(profile.serial==9 and profile.body==actor.initial_body and first.get_shader_parameter("use_hue") and palette==Hue.palette(33),tag+": received NPC item hue selects the native dye palette")
		await process_frame
		game.feed(equipment(0x40000101,0x1517,5,203));profile=game.appearance_for(9)
		actor.apply_server_appearance(game.entities[9],profile.equipment,profile);shirt=piece(visual,"shirt")
		var changed:=shirt.get_surface_override_material(0) as ShaderMaterial
		check(changed.get_shader_parameter("hue_palette")==Hue.palette(203) and palette!=changed.get_shader_parameter("hue_palette") and is_equal_approx(visual.animator.current_animation_position,.2),tag+": in-game dye update changes the item without restarting the walk")
		check(visual.native_cosmetics.hair_hue==1118 and (female or visual.native_cosmetics.beard_hue==1102) and game.appearance_for(9).statistics.is_empty(),tag+": clothing tint preserves independent hair/beard colour and unknown NPC statistics")
		var raw: Dictionary={}
		for item: Dictionary in visual.server_equipment:
			if int(item.layer)==5:raw=item
		check(raw.id==0x1517 and raw.hue==203 and raw.serial==0x40000101,tag+": native garment identity, serial and hue remain unchanged in the profile")
		await process_frame
		visual.set_equipment([{"id":0x1517,"hue":0x8000|33}]);shirt=piece(visual,"shirt")
		check((shirt.get_surface_override_material(0) as ShaderMaterial).get_shader_parameter("partial_hue"),tag+": native partial-hue flag reaches the garment shader")
		check(preload("res://Presentation/HumanActions.gd").resolve({"body":actor.initial_body,"protocol":"classic","action":5})=="Fidget_Talk" and preload("res://Presentation/HumanActions.gd").resolve({"body":actor.initial_body,"protocol":"classic","action":6})=="Fidget_Look" and visual.animator.has_animation("Fidget_Talk") and visual.animator.has_animation("Fidget_Look"),tag+": the first two original fidget groups have prepared replacements")
		# Equipment replacement queues old mesh nodes for deletion. Let those
		# nodes leave the tree before destroying their shared skeleton/materials.
		await process_frame
		game.queue_free();actor.queue_free()
		await process_frame
	print("HUMAN WARDROBE BATCH: %d passed / %d total" % [checks-failures,checks]);quit(0 if failures==0 else 1)
