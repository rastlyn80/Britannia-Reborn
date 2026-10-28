extends SceneTree
const Visual=preload("res://Presentation/HumanVisual.gd")
const Wardrobe=preload("res://Presentation/HumanWardrobe.gd")
const Hue=preload("res://Presentation/HumanHue.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok:print("PASS ",label)
	else:failures+=1;push_error(label)
func part(actor: Node3D,name: String) -> MeshInstance3D:
	for mesh: MeshInstance3D in actor.parts:
		if mesh.name.begins_with("Extra_"+name):return mesh
	return null
func run() -> void:
	check(Wardrobe.resolve([{"id":0x170b},{"id":0x170f}]).bits==0,"low shoes replace the boot silhouette without hiding calves")
	var covered:=Wardrobe.resolve([{"id":0x1517},{"id":0x1f7b},{"id":0x1515},{"id":0x1f03}])
	check(not covered.pieces.has("shirt") and not covered.pieces.has("doublet") and covered.pieces.has("cloak"),"outer robe conceals torso layers and retains the separate cloak")
	for female in [false,true]:
		var actor:=Visual.new();actor.female=female;root.add_child(actor)
		var tag:="female" if female else "male"
		actor.play("Walk",0.);actor.animator.seek(.2,true);actor.animator.pause()
		for entry in [[0x1f7b,"doublet"],[0x1515,"cloak"],[0x170f,"shoes"],[0x170d,"sandals"]]:
			actor.set_equipment([{"id":entry[0],"hue":203}]);var mesh:=part(actor,entry[1])
			check(mesh!=null and mesh.get_node(mesh.skeleton)==actor.skeleton and actor.missing_art.is_empty(),tag+": "+entry[1]+" uses the native human rig")
			await process_frame
		actor.set_equipment([{"id":0x1517,"hue":33},{"id":0x1f7b,"hue":203},{"id":0x1515,"hue":1135},{"id":0x170f,"hue":1102}])
		var materials: Array=[];var colours: Array=[]
		for name in ["shirt","doublet","cloak","shoes"]:
			var mat:=part(actor,name).get_surface_override_material(0) as ShaderMaterial
			materials.append(mat);colours.append(mat.get_shader_parameter("hue_palette"))
		check(materials[0]!=materials[1] and materials[1]!=materials[2] and colours==[Hue.palette(33),Hue.palette(203),Hue.palette(1135),Hue.palette(1102)],tag+": shirt, doublet, cloak and shoes retain independent native dyes")
		check(is_equal_approx(actor.animator.current_animation_position,.2),tag+": layered wardrobe changes preserve walking phase")
		await process_frame
		var valid:=true
		var ids:=[0x1fa1,0x1539,0x170b,0x1f03,0x278f]
		for bits in 32:
			var worn: Array=[{"id":0x170f},{"id":0x13c6}]
			for i in 5:
				if bits&(1<<i):worn.append({"id":ids[i]})
			actor.set_equipment(worn)
			valid=valid and actor.missing_art.is_empty() and actor.parts.any(func(mesh: MeshInstance3D):return mesh.name.begins_with("Body")) and part(actor,"shoes")!=null
			await process_frame
		check(valid,tag+": closed-shoe and glove coverage compose across the existing 32 outfits")
		actor.set_equipment([{"id":0x1515}]);await process_frame
		var body: MeshInstance3D=actor.model.find_children("Body*","MeshInstance3D",true,false)[0]
		check(body.visible and actor.outfit_bits==0,tag+": cloak alone retains the complete body")
		actor.set_equipment([{"id":0x170d}]);await process_frame
		check(body.visible and not actor.parts.any(func(mesh: MeshInstance3D):return mesh.name.begins_with("Body")),tag+": sandals retain exposed toes and ankles")
		actor.set_equipment([{"id":0x170f}]);await process_frame
		check(body.visible and not actor.parts.any(func(mesh: MeshInstance3D):return mesh.name.begins_with("Body")),tag+": low shoes retain the exposed instep and ankle without a cut-off gap")
		for hair_id in [0x203c,0x203d]:
			var family: String=Wardrobe.HAIR[hair_id]
			for outfit in [[0x1517,"layered"],[0x1f03,"layered"],[0x1515,"layered"],[0x278f,"hood"],[0x1715,"covered"],[0x1412,"covered"]]:
				actor.set_equipment([{"id":hair_id,"hue":1118,"layer":11},{"id":outfit[0]}]);await process_frame
				var tail:=part(actor,"hair_"+family+"_"+str(outfit[1]))
				check(tail!=null and tail.visible and actor.native_cosmetics.hair_id==hair_id and actor.native_cosmetics.hair_hue==1118,tag+": "+family+" stays outside garment "+str(outfit[0])+" with its native dye")
		actor.queue_free();await process_frame
	print("HUMAN CIVILIAN BATCH: %d passed / %d total" % [checks-failures,checks]);quit(0 if failures==0 else 1)
