extends SceneTree
## Clean-clone checks; requires neither original game files nor source CC0 imports.
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func run() -> void:
	var registry=preload("res://Presentation/CreatureRegistry.gd");registry.load_index()
	check(not DirAccess.dir_exists_absolute("res://local-art"),"Isolated project has no private artwork")
	check(not DirAccess.dir_exists_absolute("res://Art/Quaternius"),"Prepared scene has no dependency on original CC0 source imports")
	check(registry.supports_body(16),"Public water elemental resolves")
	var actor:=preload("res://Presentation/HumanAvatar.gd").new();actor.initial_body=16;root.add_child(actor);actor.set_physics_process(false)
	check(actor.human_visual==null and actor.horse_visual!=null,"Body 16 initializes the actual creature renderer")
	if actor.horse_visual==null:actor.free();quit(1);return
	var visual: Node3D=actor.horse_visual
	check(visual.skeleton.get_bone_count()==65,"Self-contained rig loads")
	for speed in [1.8,6.8]:
		actor.animate(true,0.,.016,speed);await process_frame
		check(visual.current_clip==("Walk" if speed<3.6 else "Run"),"Water movement replacement loads")
	for action in [4,5,6,12]:check(actor.receive_native_action({"protocol":"classic","action":action}),"Prepared attack/cast loads")
	for action: int in [7,8]:
		check(actor.receive_native_action({"protocol":"classic","action":action})
			and visual.current_clip == ("OverheadSurge" if action == 7 else "WaterHold"), "Legacy fluid action plays")
	for action: int in [17,18]:
		check(actor.receive_native_action({"protocol":"classic","action":action})
			and visual.current_clip == ("WaterArmSettle" if action == 17 else "Fidget2"),
			"Distinct Classic fluid fidget plays")
	var corpse:=preload("res://Presentation/CorpseModels.gd").build(16)
	check(corpse!=null and corpse.get_meta("corpse_body")==16 and corpse.get_child_count()==1 and corpse.get_child(0).name=="Puddle","Matching static puddle builds with no private or source artwork")
	check(corpse.find_children("*","Skeleton3D",true,false).is_empty(),"Corpse has no running skeleton")
	if corpse:root.add_child(corpse);corpse.queue_free()
	actor.queue_free();for frame in 2:await process_frame
	print("WATER DISTRIBUTION: ",checks-failures," / ",checks);quit(1 if failures else 0)
