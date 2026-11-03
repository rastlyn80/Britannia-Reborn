extends SceneTree
## Default client-registry avatar and corpse paths, with no injected entries.
const Avatar=preload("res://Presentation/HumanAvatar.gd")
const Registry=preload("res://Presentation/CreatureRegistry.gd")
const Corpses=preload("res://Presentation/CorpseModels.gd")
const EXPECTED={90:"serpents_snake_giant_lava",159:"elementals_blood_elemental",154:"walking_dead_mummy",782:"fire_ant_warrior",806:"black_ant_warrior",161:"elementals_ice_elemental"}
var checks:=0
var failures:=0
func _initialize() -> void:
	create_timer(120.).timeout.connect(func():push_error("Reviewed creature route deadline");quit(1))
	call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func run() -> void:
	Registry.load_index();var accepted_pin:=FileAccess.get_sha256("res://local-art/creatures/accepted-index.json")
	for body: int in EXPECTED:
		var entry:=Registry.entry(body)
		check(Registry.supports_body(body) and entry.get("kind","")==EXPECTED[body],"Normal client registry supports the exact reviewed body")
		for hue in [0,53,0x8035]:
			var actor:=Avatar.new();actor.initial_body=body;root.add_child(actor)
			actor.apply_server_appearance({"serial":9000000+body,"body":body,"hue":hue,"direction":0,"flags":0,"x":1100,"y":1700,"z":0},[])
			actor.set_process(false);actor.set_physics_process(false)
			var visual: Node3D=actor.horse_visual
			check(visual!=null and actor.human_visual==null,"Default avatar uses a creature renderer without a human fallback")
			check(visual.get_script().resource_path==entry.presentation_script,"Default avatar selects the checked renderer")
			check(visual.native_body==body and visual.native_hue==hue,"Default avatar preserves server body and raw hue")
			check(visual.skeleton.get_bone_count()==int(entry.stats.original.bones),"Default avatar retains the complete source rig")
			var corpse:=Corpses.build(body,hue)
			check(corpse!=null,"Default corpse factory supports the activated body")
			if corpse!=null:
				check(corpse.get_meta("graphic_id")==0x2006 and corpse.get_meta("corpse_body")==body and corpse.get_meta("native_hue")==hue,"Default corpse preserves native graphic/body/hue")
				check(corpse.find_children("*","Skeleton3D",true,false).is_empty() and corpse.find_children("*","AnimationPlayer",true,false).is_empty(),"Default corpse is static")
				corpse.free()
			actor.free()
	check(accepted_pin==FileAccess.get_sha256("res://local-art/creatures/accepted-index.json"),"Normal route check leaves the active index unchanged")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../work/creatures/route-promotion"))
	FileAccess.open("res://../work/creatures/route-promotion/normal-routes.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"accepted_index_sha256":accepted_pin,"test_sha256":FileAccess.get_sha256("res://Presentation/ReviewedCreatureRouteTests.gd"),"scope":"Six default client-registry actual avatars and static native-graphic corpses across three raw hues; no candidate injection, live login or native-server behaviour claim."},"\t"))
	print("REVIEWED DEFAULT ROUTES: ",checks," checks / ",failures," failures");quit(1 if failures else 0)
