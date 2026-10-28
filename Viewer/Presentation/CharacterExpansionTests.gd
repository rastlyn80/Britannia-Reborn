extends SceneTree
const Game = preload("res://Network/GameSession.gd")
const Wire = preload("res://Network/LoginProtocol.gd")
const Look = preload("res://Network/MobileAppearance.gd")
const Wardrobe = preload("res://Presentation/HumanWardrobe.gd")
const Visual = preload("res://Presentation/HumanVisual.gd")
var checks := 0
var failures := 0
var started := Time.get_ticks_msec()
func _process(_delta: float) -> bool:
	if Time.get_ticks_msec()-started>45000:
		push_error("Character expansion test watchdog timeout")
		quit(1)
	return false
func check(ok: bool, label: String) -> void:
	checks+=1
	if ok: print("PASS ",label)
	else:
		failures+=1
		push_error(label)
func equip(serial: int, id: int, layer: int, hue: int) -> PackedByteArray:
	var p:=PackedByteArray([0x2e])
	p.append_array(Wire.uint_be(serial,4));p.append_array(Wire.uint_be(id,2));p.append_array(PackedByteArray([0,layer]));p.append_array(Wire.uint_be(7,4));p.append_array(Wire.uint_be(hue,2))
	return p
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var creation:=Game.creation_packet("Styled Man",2,1,false,{"skin_hue":1021,"hair_id":0x203d,"hair_hue":1147,"beard_id":0x204d,"beard_hue":1102})
	check(Wire.read_be(creation,82,2)==1021 and Wire.read_be(creation,84,2)==0x203d and Wire.read_be(creation,86,2)==1147 and Wire.read_be(creation,88,2)==0x204d and Wire.read_be(creation,90,2)==1102,"native creation packet keeps independent skin, hair and beard fields")
	var game:=Game.new()
	root.add_child(game);game.set_process(false);game.player.serial=42
	game.entities[7]={"serial":7,"body":0x190,"hue":1007,"flags":4,"notoriety":2}
	game.entity_names[7]="Test artisan"
	game.feed(equip(0x40000100,0x203c,11,1107));game.feed(equip(0x40000101,0x204d,16,1118))
	game.feed(PackedByteArray([0xa1,0,0,0,7,0,80,0,61]))
	var profile: Dictionary=game.appearance_for(7)
	check(profile.hair_id==0x203c and profile.hair_hue==1107 and profile.beard_id==0x204d and profile.beard_hue==1118,"NPC profile preserves separate native hair/beard types and colours")
	check(profile.serial==7 and profile.body==400 and profile.skin_hue==1007 and profile.name=="Test artisan" and profile.statistics.hits==61 and profile.statistics.hits_max==80,"NPC reference, body, skin, name and received vitals remain authoritative")
	check(not profile.statistics.has("str") and not profile.statistics.has("int"),"unreceived NPC statistics remain unknown")
	profile.statistics.hits=1
	check(game.appearance_for(7).statistics.hits==61,"presentation profile cannot mutate authoritative state")
	game.feed(equip(0x40000100,0x203d,11,1120))
	check(game.appearance_for(7).hair_id==0x203d and game.appearance_for(7).hair_hue==1120 and game.appearance_for(7).beard_hue==1118,"live hair update retains independent beard colour")
	game.feed(PackedByteArray([0x1d,0x40,0,1,1]))
	check(game.appearance_for(7).beard_id==0 and game.appearance_for(7).hair_id==0x203d,"beard removal clears only facial hair")
	var action:=PackedByteArray([0x6e,0,0,0,7,0,12,0,8,0,2,1,1,3])
	game.feed(action)
	check(game.last_mobile_actions[7].action==12 and game.last_mobile_actions[7].reverse and game.last_mobile_actions[7].repeat_count==2,"native classic animation request retained without invented animation mapping")
	var modern:=PackedByteArray([0xe2,0,0,0,7,0,18,0,5,4])
	game.feed(modern)
	check(game.last_mobile_actions[7].protocol=="new" and game.last_mobile_actions[7].action==18 and game.last_mobile_actions[7].delay==4,"native new animation request retained independently of body family")
	var malformed:=true
	for p in [action,modern]:
		for length in p.size(): malformed=malformed and Look.action(p.slice(0,length)).is_empty()
	check(malformed,"all truncated animation requests rejected")
	check(Wardrobe.resolve([{"id":0x1516}]).pieces.outer_legs.asset=="skirt" and Wardrobe.resolve([{"id":0x1537}]).pieces.outer_legs.asset=="kilt","native skirt and kilt have distinct pieces instead of trousers")
	check(Wardrobe.resolve([{"id":0x1516},{"id":0x1f03}]).pieces.is_empty(),"outer robe conceals the inner skirt deterministically")
	var wardrobe:=Wardrobe.resolve([{"id":0x13c6},{"id":0x1412},{"id":0xf5e}])
	check(wardrobe.gloves and wardrobe.pieces.head.asset=="closed_helmet" and wardrobe.pieces.weapon.asset=="sword","native gloves, closed helmet and sword resolve independently")
	game.free()
	for female in [false,true]:
		var actor:=Visual.new();actor.female=female;root.add_child(actor)
		actor.play("Walk",0.);actor.animator.seek(.2,true);actor.animator.pause()
		var rig: Skeleton3D=actor.skeleton
		var animator: AnimationPlayer=actor.animator
		var valid:=true
		var source_ids:=[0x1fa1,0x1539,0x170b,0x1f03,0x278f]
		for bits in 32:
			var items: Array=[{"id":0x13c6,"layer":7}]
			for i in 5:
				if bits&(1<<i): items.append({"id":source_ids[i]})
			actor.set_equipment(items)
			valid=valid and actor.missing_art.is_empty() and actor.animator==animator and actor.skeleton==rig and is_equal_approx(animator.current_animation_position,.2)
			await process_frame
		check(valid,"%s: 32 glove/body-coverage combinations preserve rig and gait" % ("female" if female else "male"))
		valid=true
		for hair in [0,0x203b,0x203c,0x203d,0x2045,0x2047]:
			for beard in [0,0x203e,0x203f,0x2040,0x2041,0x204b,0x204c,0x204d]:
				actor.set_equipment([{"id":hair,"layer":11,"hue":1107},{"id":beard,"layer":16,"hue":1118}])
				valid=valid and actor.native_cosmetics.hair_id==hair and actor.native_cosmetics.beard_id==beard and actor.missing_art.is_empty()
				await process_frame
		check(valid,"%s: bald/five hair families and all seven native beard styles retain independent hues" % ("female" if female else "male"))
		for id in [0x1516,0x1537,0x140c,0x1412,0xf5e,0x1439,0xe81]:
			actor.set_equipment([{"id":id}])
			check(actor.missing_art.is_empty() and not actor.parts.is_empty(),"fitted %s piece 0x%04x loads on shared skeleton" % ["female" if female else "male",id])
		actor.set_equipment([{"id":0xf5e}])
		await process_frame
		check(actor.grip.holding and actor.grip.rotations.size()>=12,"authored right-hand grip engages for held weapon")
		actor.set_equipment([])
		check(not actor.grip.holding,"weapon removal releases the hand grip")
		actor.set_equipment([{"id":0x999,"layer":11,"hue":1250}])
		check(actor.native_cosmetics.hair_id==0x999 and actor.missing_art.has(0x999),"unknown native hair identity is preserved and reported as a substitute")
		actor.queue_free();await process_frame
	var art=preload("res://Network/Artwork.gd")
	art.load_local()
	art.hues["9000"]=Array().duplicate()
	var red: Array=[];var blue: Array=[]
	for i in 32: red.append(31<<10);blue.append(31)
	art.hues["9000"]=red;art.hues["9001"]=blue
	var hue=preload("res://Presentation/HumanHue.gd")
	var red_palette: Texture2D=hue.palette(9001)
	var blue_palette: Texture2D=hue.palette(9002)
	check(red_palette!=blue_palette and red_palette.get_image().get_pixel(31,0).r>.99 and blue_palette.get_image().get_pixel(31,0).b>.99,"independent native RGB555 hue palettes remain separate between characters")
	art.hues.erase("9000");art.hues.erase("9001")
	var recon:=preload("res://Presentation/Reconstruction.gd").new()
	var node:=Node3D.new()
	var prop:=MeshInstance3D.new()
	var cube:=BoxMesh.new()
	var imported:=ArrayMesh.new();imported.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,cube.surface_get_arrays(0))
	prop.mesh=imported;node.add_child(prop)
	var original_count: int=prop.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
	recon.tint_prop(node,"green")
	check(prop.mesh!=imported and prop.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()==original_count,"new world props without vertex colours retain their geometry during tinting")
	node.free()
	print("CHARACTER EXPANSION: %d passed / %d total" % [checks-failures,checks])
	quit(0 if failures==0 else 1)
