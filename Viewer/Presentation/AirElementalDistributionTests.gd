extends SceneTree
## Actual public avatar and corpse without private marker, carrier or game input.
const Avatar=preload("res://Presentation/HumanAvatar.gd")
const Registry=preload("res://Presentation/CreatureRegistry.gd")
const Air=preload("res://Presentation/AirElementalVisual.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
const Corpses=preload("res://Presentation/CorpseModels.gd")
const Surface=preload("res://Presentation/AirElementalSurface.gdshader")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;if failures<15:push_error(label)
func run() -> void:
	for missing in ["res://local-art","res://../Server","res://Art/Creatures/Water","res://Art/Quaternius"]:
		check(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(missing)),"No private source, carrier or server required: "+missing)
	check(Registry.entry(13).get("assets",{}).get("modern")=="res://Art/Creatures/Air/air-elemental.scn","Installed public index routes actual native body13")
	var actor:=Avatar.new();actor.initial_body=13;root.add_child(actor);actor.set_physics_process(false)
	var visual: Node3D=actor.horse_visual;check(visual is Air and actor.human_visual==null,"Actual public avatar creates the wind presenter")
	visual.set_process(false);visual.set_physics_process(false)
	check(visual.original_marker==null,"Public actor needs no proprietary rigid death marker")
	var rig: Skeleton3D=visual.skeleton;check(rig.get_bone_count()==65,"Complete CC0 rig loads independently of donor/carrier")
	var meshes: Array=visual.model.find_children("*","MeshInstance3D",true,false)
	check(meshes.size()==2 and visual.model.find_child("CloudBody",true,false)!=null and visual.model.find_child("Dust",true,false)!=null,"Public geometry contains cloud/vortex and separate dry footprint")
	check(visual.entry.stats.modern.clips.size()==15,"Public index declares all fifteen saved action categories")
	for category: String in visual.entry.stats.modern.clips:
		check(visual.animator.has_animation(category),"Actual public animation library includes saved category: "+category)
	check(visual.animator.get_animation_list().size()==17,"Runtime also provides its explicitly synthesized Eat/LieDown compatibility poses")
	var samples:=0
	for category: String in visual.animator.get_animation_list():
		check((visual.animator.get_animation(category).loop_mode==Animation.LOOP_LINEAR)==(category in visual.entry.loop_categories),"Saved category loop state matches declared intent")
		visual.play(category,0.)
		for phase in [0.,.23,.61,.9999]:
			visual.animator.seek(visual.animator.current_animation_length*phase,true);visual.animator.pause();rig.force_update_all_bone_transforms()
			check(absf(visual.wind_phase-TAU*phase)<.001,"Synchronous pose sample drives normalized shader phase")
			for mesh: MeshInstance3D in meshes:
				var box:=Geometry.deformed_bounds(mesh,rig) if mesh.skin!=null else mesh.global_transform*mesh.mesh.get_aabb();samples+=1
				check(box.position.is_finite() and box.size.is_finite() and box.size.length()>.001 and box.size.length()<4.,"Complete actual cloud/dust geometry remains finite and nonempty")
			if category.begins_with("Death") and phase>.99:
				check(not visual.model.find_child("CloudBody",true,false).visible and visual.model.find_child("Dust",true,false).visible,"Final death shows dry footprint instead of living cloud")
	for hue in [0,53,0x8035,0x4001]:
		actor.apply_server_appearance({"body":13,"hue":hue},[])
		check(visual.native_body==13 and visual.native_hue==hue,"Raw native body/hue bits survive source-free appearance updates")
		for mesh: MeshInstance3D in meshes:
			var material:=mesh.get_active_material(0) as ShaderMaterial
			check(material!=null and material.shader==Surface,"Public wind shader is packaged and bound")
			check(bool(material.get_shader_parameter("partial_hue"))==bool(hue&0x8000),"Partial hue flag remains exact")
			check(bool(material.get_shader_parameter("dust"))==(mesh.name=="Dust"),"Dry footprint retains its distinct shader mode")
			if hue==0x4001:check(not bool(material.get_shader_parameter("use_hue")),"Spectral sentinel never becomes ordinary dye one")
	for code in [4,5,6,10,11,12,17,18]:
		visual.dead=false;visual.action_remaining=0.
		check(visual.receive_action({"protocol":"classic","action":code,"frame_count":6,"repeat_count":1,"delay":0}),"Actual source-free avatar consumes explicit native action")
	actor.free()
	var corpse:=Corpses.build(13,0x8035);check(corpse!=null,"Public native body produces its static cadaver")
	if corpse!=null:
		check(corpse.find_children("*","Skeleton3D",true,false).is_empty() and corpse.find_children("*","AnimationPlayer",true,false).is_empty(),"Static corpse has no live rig or animation")
		check(corpse.get_meta("native_hue")==0x8035 and corpse.get_meta("corpse_body")==13,"Cadaver retains native identity and raw partial hue")
		var surfaces:=0
		for mesh: MeshInstance3D in corpse.get_children():
			for surface in mesh.mesh.get_surface_count():
				surfaces+=1;var arrays:=mesh.mesh.surface_get_arrays(surface)
				check(arrays[Mesh.ARRAY_VERTEX].size()>0 and arrays[Mesh.ARRAY_BONES]==null and arrays[Mesh.ARRAY_WEIGHTS]==null,"Actual static surface contains vertices without skin bindings")
				var material:=mesh.get_active_material(surface) as ShaderMaterial
				check(bool(material.get_shader_parameter("dust")) and absf(float(material.get_shader_parameter("phase"))-TAU)<.001 and not material.shader.code.contains("TIME"),"Dry footprint freezes final shader phase without a running clock")
		check(surfaces==1,"Only visible final dust survives, with no hidden cloud or source marker");corpse.free()
	print("AIR DISTRIBUTION: ",checks-failures," / ",checks," checks; ",samples," complete skins");quit(1 if failures else 0)
