extends SceneTree
## Real avatar/death/world-item presenters with recorded native clothing.
## Trial routes exist only in this process and never enter the accepted index.
const Registry=preload("res://Presentation/CreatureRegistry.gd")
const Avatar=preload("res://Presentation/HumanAvatar.gd")
const Visual=preload("res://Presentation/SourceMageVisual.gd")
const Corpses=preload("res://Presentation/CorpseModels.gd")
const Deaths=preload("res://Presentation/CreatureDeaths.gd")
const Game=preload("res://Network/GameSession.gd")
const Wire=preload("res://Network/LoginProtocol.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
var checks:=0
var failures:=0
var viewport: SubViewport
var preparation:="res://local-art/creatures/mages/preparation.json"
var native_report:="res://../work/creatures/evil-mages/native-identity-probe.json"
var output:="res://../work/creatures/evil-mages/equipment-bridge"
var trial_folder:=""
class Arena extends Node3D:
	var avatars: Dictionary={}
	var world: Dictionary={"originX":0,"originY":0,"width":100,"height":100}
	var movement_surface: Node
	var reconstruction: Node
	func entity_point(x: int,y: int,z: int) -> Vector3:return Vector3(x,float(z)/5.,y)
class Items extends "res://Presentation/WorldItems.gd":
	# This probe has no streamed terrain. All other item/death/corpse code runs.
	func request_contact_refresh() -> void:pass
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--preparation="):preparation=arg.trim_prefix("--preparation=")
		if arg.begins_with("--native-report="):native_report=arg.trim_prefix("--native-report=")
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		if arg.begins_with("--trial-folder="):trial_folder=arg.trim_prefix("--trial-folder=")
	create_timer(300.).timeout.connect(func():push_error("Mage equipment bridge deadline");quit(1));call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;if failures<30:push_error(label)
func capture() -> Image:
	for frame in 3:await process_frame
	await RenderingServer.frame_post_draw;return viewport.get_texture().get_image()
func difference(a: Image,b: Image,region: Rect2i=Rect2i()) -> int:
	if region.size==Vector2i.ZERO:region=Rect2i(Vector2i.ZERO,a.get_size())
	region=region.intersection(Rect2i(Vector2i.ZERO,a.get_size()));var count:=0
	for y in range(region.position.y,region.end.y,2):
		for x in range(region.position.x,region.end.x,2):
			var d:=a.get_pixel(x,y)-b.get_pixel(x,y)
			if absf(d.r)+absf(d.g)+absf(d.b)>.025:count+=1
	return count
func surface(node: Node3D) -> ShaderMaterial:
	return (node.find_children("*","MeshInstance3D",true,false)[0] as MeshInstance3D).get_active_material(0) as ShaderMaterial
func changed(worn: Array,layer: int,hue: int) -> Array:
	var result:=worn.duplicate(true)
	for item: Dictionary in result:
		if int(item.layer)==layer:item.hue=hue
	return result
func packet(killed: int,corpse: int) -> PackedByteArray:
	var p:=PackedByteArray([0xaf]);p.append_array(Wire.uint_be(killed,4));p.append_array(Wire.uint_be(corpse,4));p.append_array(Wire.uint_be(0,4));return p
func corpse_packet(corpse: int,worn: Array) -> PackedByteArray:
	var p:=PackedByteArray([0x89,0,0]);p.append_array(Wire.uint_be(corpse,4))
	for item: Dictionary in worn:p.append(int(item.layer)+1);p.append_array(Wire.uint_be(int(item.serial),4))
	p.append(0);p[1]=(p.size()>>8)&255;p[2]=p.size()&255;return p
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var prep: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(preparation));var native: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(native_report));var rows: Array=[]
	Registry.load_index()
	for original: Dictionary in prep.models:
		var record:=original.duplicate(true);record.presentation_script="res://Presentation/SourceMageVisual.gd";record.native_equipment_layers=[22,6,3];record.camera_height=1.8
		if not trial_folder.is_empty():record.assets={"modern":trial_folder+str(record.kind)+"-dyed-trial.gltf"}
		for identity: Dictionary in record.bodies:Registry.entries[int(identity.body)]=record
	viewport=SubViewport.new();viewport.size=Vector2i(1000,900);viewport.own_world_3d=true;viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport);preload("res://Presentation/ItemStudio.gd").studio_lights(viewport)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=3.;viewport.add_child(camera)
	var game:=Game.new();root.add_child(game);game.set_process(false)
	var arena:=Arena.new();viewport.add_child(arena);var items:=Items.new();arena.add_child(items);items.configure(arena,game)
	var deaths:=Deaths.new();arena.add_child(deaths);deaths.configure(arena,game,items);deaths.set_process(false)
	check(Corpses.supports_equipment(400) and Corpses.supports_equipment(401) and not Corpses.supports_equipment(92),"Human equipment refresh preserved; ordinary source creatures remain outside garment refresh")
	for body: int in [124,125,126]:
		var witness: Dictionary=native.records.filter(func(row: Dictionary):return int(row.body)==body and int(row.client)==0)[0];var worn: Array=witness.equipment.duplicate(true)
		for index in worn.size():worn[index].serial=0x40100000+body*16+index
		var entity: Dictionary={"body":body,"hue":0,"serial":10000+body,"direction":5,"x":0,"y":0,"z":0};var actor:=Avatar.new();actor.initial_body=body;arena.add_child(actor);actor.set_physics_process(false);actor.set_process(false);actor.apply_server_appearance(entity,worn);arena.avatars[int(entity.serial)]=actor
		var visual: Node3D=actor.horse_visual;visual.set_process(false);visual.set_physics_process(false);visual.contact.active=false;visual.contact.enabled=false
		check(visual is Visual and visual.native_body==body and visual.skeleton.get_bone_count()==36,"Actual avatar retains source mage identity/rig")
		check(Corpses.supports_equipment(body) and visual.server_equipment==worn,"Actual avatar receives recorded native equipment")
		visual.play("Idle",0.);visual.animator.seek(.2,true);visual.animator.pause();var rig: Skeleton3D=visual.skeleton;rig.force_update_all_bone_transforms();var mesh: MeshInstance3D=visual.model.find_children("*","MeshInstance3D",true,false)[0];var box:=Geometry.deformed_bounds(mesh,rig);camera.position=box.get_center()+Vector3(.5,.15,3.);camera.look_at(box.get_center())
		var face:=Vector2i(camera.unproject_position(rig.to_global(rig.get_bone_global_pose(rig.find_bone("bip01 head")).origin)));var face_region:=Rect2i(face-Vector2i(12,12),Vector2i(24,24));var base:=await capture();base.save_png(output+"/body-%d-native.png"%body)
		var robe_worn:=changed(worn,22,53);actor.apply_server_appearance(entity,robe_worn);var robe:=await capture();var robe_pixels:=difference(base,robe);check(robe_pixels>100 and difference(base,robe,face_region)<10,"Actual avatar robe dye changes costume while preserving sampled face")
		# An unrelated container/serial change must not affect the surface key.
		var old_material:=surface(visual);var unrelated:=robe_worn.duplicate(true);unrelated.append({"layer":21,"id":3701,"hue":99});visual.set_equipment(unrelated);check(surface(visual)==old_material,"Irrelevant backpack record preserves material instance")
		visual.set_equipment(robe_worn);robe_worn[0].hue=77;check(visual.server_equipment[0].hue!=77,"Renderer owns a deep equipment snapshot")
		actor.apply_server_appearance(entity,worn)
		var hues: Array=[]
		for layer in ([22,3] if body==124 else [22,6,3]):
			for hue in [0,53,0x8035]:
				var altered:=changed(worn,layer,hue);actor.apply_server_appearance(entity,altered);var mat:=surface(visual);var slot:=str({22:"robe",6:"hat",3:"shoes"}[layer]);check(mat.get_shader_parameter(slot+"_present") and bool(mat.get_shader_parameter(slot+"_partial"))==bool(hue&0x8000),"Present zero/full/partial garment hues retain independent native bits");check(bool(mat.get_shader_parameter("use_"+slot))==(hue!=0),"Present hue zero restores source garment colour")
				hues.append({"layer":layer,"hue":hue})
		actor.apply_server_appearance(entity,changed(worn,22,53));var corpse_id:=0x40030000+body;var before: Array=visual.server_equipment.duplicate(true);game.entities[int(entity.serial)]=entity.duplicate(true);game._handle(packet(int(entity.serial),corpse_id));check(deaths.active.has(int(entity.serial)),"Decoded native death starts actual equipment-aware snapshot")
		var dying: Node3D=deaths.active[int(entity.serial)].visual;check(dying.server_equipment==before and surface(dying).get_shader_parameter("robe_palette")==surface(visual).get_shader_parameter("robe_palette"),"Death snapshot retains actual worn hues")
		actor.apply_server_appearance(entity,changed(worn,22,0x8035));check(dying.server_equipment==before and not surface(dying).get_shader_parameter("robe_partial"),"Later mobile gear changes cannot recolour in-flight death")
		var world_item: Dictionary={"serial":corpse_id,"id":0x2006,"amount":body,"hue":0,"x":0,"y":0,"z":0,"facet":1};game.world_items[corpse_id]=world_item
		for item: Dictionary in before:game.known_items[int(item.serial)]=item.merged({"container":corpse_id},true)
		game._handle(corpse_packet(corpse_id,before));items.upsert(corpse_id,world_item);var holder: Node3D=items.nodes[corpse_id];deaths._update_corpse(corpse_id)
		check(not holder.visible and holder.get_meta("corpse_worn")==items.corpse_worn(corpse_id),"Actual corpse item keeps decoded native clothing while death holds it hidden")
		var frozen: Node3D=holder.get_node("CorpseVisual");check(frozen.get_meta("static_cadaver") and frozen.find_children("*","Skeleton3D",true,false).is_empty(),"Equipment-aware cadaver is frozen and rig-free")
		var frozen_mesh: MeshInstance3D=frozen.find_children("*","MeshInstance3D",true,false)[0];var frozen_colors: PackedColorArray=frozen_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR];check(frozen_colors==mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR],"Static cadaver retains every semantic garment colour value exactly")
		var prior_instance:=holder.get_instance_id();items.refresh_corpses();check(items.nodes[corpse_id].get_instance_id()==prior_instance,"Unchanged corpse gear does not rebuild cadaver")
		var robe_serial:=0
		for item: Dictionary in before:
			if int(item.layer)==22:robe_serial=int(item.serial)
		game.known_items[robe_serial].hue=0x8035;items.refresh_corpse_equipment(corpse_id);holder=items.nodes[corpse_id];check(holder.get_instance_id()!=prior_instance and surface(holder.get_node("CorpseVisual")).get_shader_parameter("robe_partial"),"Later corpse item hue rebuilds actual frozen garment material")
		check(not holder.visible,"Equipment refresh retains death-held corpse visibility")
		prior_instance=holder.get_instance_id();game.known_items[robe_serial].container=999;items.refresh_corpses();holder=items.nodes[corpse_id];check(holder.get_instance_id()!=prior_instance and not surface(holder.get_node("CorpseVisual")).get_shader_parameter("robe_present"),"Looted clothing stops tinting integral base costume")
		deaths.finish(int(entity.serial));check(holder.visible,"Final static cadaver becomes visible after native death")
		var asset:=Registry.asset_path(Registry.entry(body))
		rows.append({"body":body,"native_class":witness.native_class,"robe_changed_pixels":robe_pixels,"hue_cases":hues,"vertices":frozen_colors.size(),"asset_sha256":FileAccess.get_sha256(asset),"import_sha256":FileAccess.get_sha256(asset+".import"),"scope":"Recorded native equipment; actual avatar, decoded 0xAF/0x89, death snapshot, WorldItems upsert, hue/loot refresh and frozen cadaver. No native socket or streamed-terrain test in this process."})
		items.remove(corpse_id);game.world_items.erase(corpse_id);arena.avatars.erase(int(entity.serial));actor.free()
		for frame in 3:await process_frame
	var runtime: Dictionary={}
	for filename in ["SourceMageEquipmentTests.gd","SourceMageVisual.gd","SourceMageSupport.gd","SourceMageMaterial.gd","SourceMageSurface.gdshader","HumanAvatar.gd","CorpseModels.gd","CreatureDeaths.gd","WorldItems.gd"]:runtime[filename]=FileAccess.get_sha256("res://Presentation/"+filename)
	FileAccess.open(output+"/validation.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"in_memory_routes_only":true,"private_trial_folder":not trial_folder.is_empty(),"bodies":rows,"runtime_sha256":runtime,"test_sha256":FileAccess.get_sha256("res://Presentation/SourceMageEquipmentTests.gd"),"preparation_sha256":FileAccess.get_sha256(preparation),"native_report_sha256":FileAccess.get_sha256(native_report)}));print("MAGE EQUIPMENT BRIDGE: ",checks," / ",failures," failures");quit(1 if failures else 0)
