extends SceneTree
## Normal registry/avatar/corpse checks; accepts future batch preparation paths.
const Avatar=preload("res://Presentation/HumanAvatar.gd")
const Registry=preload("res://Presentation/CreatureRegistry.gd")
const Corpses=preload("res://Presentation/CorpseModels.gd")
var preparations:=PackedStringArray(["source_family_batch/preparation.json","source_reused_variants/preparation.json"])
var checks:=0
var failures:=0
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--preparation="):preparations=arg.trim_prefix("--preparation=").split(",",false)
	create_timer(120.).timeout.connect(func():push_error("Creature batch normal-route deadline");quit(1))
	call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func run() -> void:
	Registry.load_index();var pin:=FileAccess.get_sha256("res://local-art/creatures/accepted-index.json");var bodies: Array=[]
	for relative: String in preparations:
		var prepared: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://local-art/creatures/"+relative))
		for row: Dictionary in prepared.models:
			for identity: Dictionary in row.bodies:
				var body:=int(identity.body);var entry:=Registry.entry(body);bodies.append(body)
				check(Registry.supports_body(body) and entry.get("kind","")==row.kind,"Normal registry selects the exact checked body/kind")
				for hue in [0,0x480 if body==155 else 53,0x8035]:
					var actor:=Avatar.new();actor.initial_body=body;root.add_child(actor)
					actor.apply_server_appearance({"serial":9000000+body,"body":body,"hue":hue,"direction":0,"flags":0,"x":1100,"y":1700,"z":0},[])
					actor.set_process(false);actor.set_physics_process(false)
					var visual: Node3D=actor.horse_visual;visual.contact.active=false
					var expected_script: String = row.presentation_script
					if body == 155 and entry.get("classic_gesture_batch", "") == "avenger_rotting_actions":
						expected_script = "res://Presentation/RottingCorpseActionsVisual.gd"
						check(visual.get_script().get_base_script().resource_path == row.presentation_script,
							"Rotting Corpse retains its original skin and contact renderer")
					if body == 753 and entry.has("preferred_uop_native_sha256"):
						expected_script = "res://Presentation/ArchiveSourcePreservingGestureVisual.gd"
						check(visual.get_script().get_base_script().resource_path == row.presentation_script,
							"Enslaved Gargoyle retains its original skin and contact renderer")
					check(visual!=null and actor.human_visual==null and visual.get_script().resource_path==expected_script,"Actual normal avatar selects the checked creature renderer")
					check(visual.native_body==body and visual.native_hue==hue,"Actual avatar preserves server body and raw hue")
					check(visual.skeleton.get_bone_count()==int(row.stats.original.bones),"Actual avatar retains every source joint")
					if row.has("asset_base_scale"):
						var base: Array=row.asset_base_scale;var target: Array=identity.scale
						var expected: Vector3=visual.default_model_scale*Vector3(float(target[0])/float(base[0]),float(target[1])/float(base[1]),float(target[2])/float(base[2]))
						check(visual.model.scale.is_equal_approx(expected),"Native target proportions use the explicit asset baseline")
					if body==155:
						for request in [{"protocol":"classic","action":12},{"protocol":"classic","action":14},{"protocol":"new","type":11}]:
							check(visual.receive_action(request) and visual.current_clip=="Cast","Unfrozen Mummy shares a real cast on body155")
					var corpse:=Corpses.build(body,hue)
					check(corpse!=null,"Normal static corpse factory supports the body")
					if corpse!=null:
						check(corpse.get_meta("graphic_id")==0x2006 and corpse.get_meta("corpse_body")==body and corpse.get_meta("native_hue")==hue,"Static corpse retains native graphic/body/raw hue")
						check(corpse.find_children("*","MeshInstance3D",true,false).size()>0 and corpse.find_children("*","Skeleton3D",true,false).is_empty() and corpse.find_children("*","AnimationPlayer",true,false).is_empty(),"Static corpse has actual geometry and no animated rig")
						corpse.free()
					actor.free()
	check(pin==FileAccess.get_sha256("res://local-art/creatures/accepted-index.json"),"Normal route checks leave the accepted index unchanged")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../work/creatures/shared-batch"))
	FileAccess.open("res://../work/creatures/shared-batch/normal-routes.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"bodies":bodies,"accepted_index_sha256":pin,"test_sha256":FileAccess.get_sha256("res://Presentation/CreatureBatchRouteTests.gd"),"scope":"Actual normal registry/avatar/static-corpse routing, native raw hue and source asset proportions; no injected entries or native-server behaviour claim."},"\t"))
	print("CREATURE BATCH NORMAL ROUTES: ",checks," checks / ",failures," failures / ",bodies.size()," bodies");quit(1 if failures else 0)
