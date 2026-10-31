extends SceneTree
## Exercise the public route with no separately installed creature artwork.
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func run() -> void:
	var registry=preload("res://Presentation/CreatureRegistry.gd")
	registry.load_index()
	if "--require-isolated" in OS.get_cmdline_user_args():
		check(not DirAccess.dir_exists_absolute("res://local-art"),"No private/local art is installed")
		check(registry.entries.size()==1,"Only the distributable bird registry is present")
	check(registry.supports_body(6),"Public manifest resolves the ordinary bird")
	var actor:=preload("res://Presentation/HumanAvatar.gd").new();actor.initial_body=6;root.add_child(actor);actor.set_physics_process(false)
	check(actor.human_visual==null and actor.horse_visual!=null,"Actual avatar initializes directly as the public bird")
	if actor.horse_visual==null:actor.free();quit(1);return
	var visual: Node3D=actor.horse_visual
	check(visual.skeleton.get_bone_count()==65,"Distributed skeleton loads")
	for speed in [1.8,6.8]:
		actor.animate(true,0.,.016,speed);await process_frame
		check(visual.current_clip==("Walk" if speed<3.6 else "Run"),"Public movement clip loads")
	check(actor.receive_native_action({"protocol":"new","type":11}),"Distributed call/cast category loads")
	var bodies=preload("res://Presentation/CorpseModels.gd")
	var posed:=bodies.posed(6)
	var corpse: Node3D=bodies.freeze(posed)
	check(corpse!=null and corpse.get_meta("corpse_body")==6 and corpse.find_children("*","Skeleton3D",true,false).is_empty(),"Matching static corpse builds without private artwork")
	posed.queue_free()
	if corpse:root.add_child(corpse);corpse.queue_free()
	actor.queue_free()
	for frame in 2:await process_frame
	print("BIRD DISTRIBUTION: ",checks-failures," / ",checks);quit(1 if failures else 0)
