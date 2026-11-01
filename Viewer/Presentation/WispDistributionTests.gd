extends SceneTree
## Installed source-only package, no local art, game inputs or donor/server.
const Avatar=preload("res://Presentation/HumanAvatar.gd")
const Registry=preload("res://Presentation/CreatureRegistry.gd")
const Wisp=preload("res://Presentation/WispVisual.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
const Corpses=preload("res://Presentation/CorpseModels.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;if failures<15:push_error(label)
func run() -> void:
	check(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://local-art")),"Clean project has no private art")
	check(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://../Server")),"Clean project has no server/game inputs")
	check(Registry.entry(58).get("assets",{}).get("modern")=="res://Art/Creatures/Wisp/wisp.scn","Actual installed public index supplies the body58 route")
	var actor:=Avatar.new();actor.initial_body=58;root.add_child(actor);actor.set_physics_process(false)
	var visual: Node3D=actor.horse_visual;check(visual is Wisp and actor.human_visual==null,"Actual standalone avatar creates the independent Wisp")
	visual.set_process(false);visual.set_physics_process(false)
	var rig: Skeleton3D=visual.skeleton;check(rig.get_bone_count()==7,"All authored bones load without any source file")
	var meshes: Array=visual.model.find_children("*","MeshInstance3D",true,false);check(meshes.size()==8,"Both core shells and six directional rays survive packaging")
	var samples:=0
	for category: String in visual.animator.get_animation_list():
		check((visual.animator.get_animation(category).loop_mode==Animation.LOOP_LINEAR)==(category in ["Idle","Walk","Run"]),"Runtime category loop state matches authored intent")
		visual.play(category,0.)
		for phase in [0.,.23,.61,.9999]:
			visual.animator.seek(visual.animator.current_animation_length*phase,true);visual.animator.pause();rig.force_update_all_bone_transforms()
			check(absf(visual.energy_phase-TAU*phase)<.001,"Actual shader phase follows synchronous saved animation sampling")
			for mesh: MeshInstance3D in meshes:
				var box:=Geometry.deformed_bounds(mesh,rig);samples+=1
				check(box.position.is_finite() and box.size.is_finite() and box.size.length()>.001 and box.size.length()<3.,"Complete actual energy skin stays finite and nonempty")
	for hue in [0,53,0x8035]:
		actor.apply_server_appearance({"body":58,"hue":hue},[]);check(visual.native_body==58 and visual.native_hue==hue,"Source-free avatar retains raw body and all hue bits")
		var core_count:=0
		for mesh: MeshInstance3D in meshes:
			var material:=mesh.get_active_material(0) as ShaderMaterial
			check(material!=null and material.shader==preload("res://Presentation/WispSurface.gdshader"),"Independent energy shader is packaged and bound")
			check(bool(material.get_shader_parameter("partial_hue"))==bool(hue&0x8000),"Partial hue flag survives absent private palette files")
			if bool(material.get_shader_parameter("core")):core_count+=1
		check(core_count==2,"Authored protected core shells stay separate from six tintable rays")
	for code in [4,10,11,12]:
		visual.dead=false;visual.action_remaining=0.
		check(visual.receive_action({"protocol":"classic","action":code,"frame_count":6,"repeat_count":1,"delay":0}),"Source-free actual avatar consumes its explicit action category")
	actor.free()
	var corpse:=Corpses.build(58,0x8035);check(corpse!=null,"Public body58 produces a source-free static cadaver")
	if corpse!=null:
		check(corpse.find_children("*","Skeleton3D",true,false).is_empty() and corpse.find_children("*","AnimationPlayer",true,false).is_empty(),"Static energy corpse has no live rig or animator")
		check(corpse.get_meta("native_hue")==0x8035 and corpse.get_meta("corpse_body")==58,"Static corpse retains exact native identity and partial hue")
		var surfaces:=0
		for mesh: MeshInstance3D in corpse.get_children():
			for surface in mesh.mesh.get_surface_count():
				surfaces+=1;var arrays:=mesh.mesh.surface_get_arrays(surface)
				check(arrays[Mesh.ARRAY_VERTEX].size()>0 and arrays[Mesh.ARRAY_BONES]==null and arrays[Mesh.ARRAY_WEIGHTS]==null,"Actual static surface contains geometry and no skin bindings")
				var material:=mesh.get_active_material(surface) as ShaderMaterial
				check(absf(float(material.get_shader_parameter("phase"))-TAU)<.001 and not material.shader.code.contains("TIME"),"Actual final Death phase is frozen without a running shader clock")
		check(surfaces==8,"All eight corpse surfaces are present in the clean package");corpse.free()
	print("WISP DISTRIBUTION: ",checks-failures," / ",checks," checks; ",samples," complete skins");quit(1 if failures else 0)
