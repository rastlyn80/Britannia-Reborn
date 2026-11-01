extends SceneTree
## This runs in a disposable project containing only public source and assets.
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func run() -> void:
	var registry=preload("res://Presentation/CreatureRegistry.gd");registry.load_index()
	check(not DirAccess.dir_exists_absolute("res://local-art"),"No private/local art is installed")
	check(registry.supports_body(151),"Public manifest resolves native dolphin body151")
	check(registry.entry(151).assets.modern=="res://Art/Creatures/Dolphin/dolphin.glb","Installed route uses the public bundle")
	var actor:=preload("res://Presentation/HumanAvatar.gd").new();actor.initial_body=151;root.add_child(actor);actor.set_physics_process(false)
	check(actor.human_visual==null and actor.horse_visual!=null,"Actual avatar creates the public dolphin without private inputs")
	if actor.horse_visual==null:actor.free();quit(1);return
	var visual: Node3D=actor.horse_visual
	check(visual.skeleton.get_bone_count()==9,"Distributed authored skeleton loads")
	check(visual.model.find_children("*","MeshInstance3D",true,false).size()==6,"All licensed facial and body surfaces are bundled")
	var mesh: MeshInstance3D=visual.model.find_children("*","MeshInstance3D",true,false)[0]
	check(mesh.get_active_material(0).shader==preload("res://Presentation/CreatureMarineSurface.gdshader"),"Actual public avatar retains marine PBR")
	for speed in [1.8,6.8]:
		actor.animate(true,0.,.016,speed);await process_frame
		check(visual.current_clip==("Walk" if speed<3.6 else "Run"),"Public swimming clip resolves")
	check(visual.contact.feet.is_empty(),"Dolphin does not invent standing foot IK")
	var ground:=StaticBody3D.new();var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(8.,.1,8.);collider.shape=shape;ground.add_child(collider);root.add_child(ground)
	actor.set_physics_process(true)
	for level in [-.3,.3]:
		ground.position.y=level-.05
		for frame in 12:await physics_frame;actor.animate(true,0.,1./60.,1.8);await process_frame
		check(is_zero_approx(actor.ground_offset) and actor.visual_root.position.is_zero_approx() and actor.global_position.is_zero_approx() and visual.contact.contacts.is_empty(),"Public waterline ignores seabed and raised deck colliders")
	actor.set_physics_process(false);ground.free()
	for group in [3,4,7]:
		check(actor.receive_native_action({"protocol":"classic","action":group}) and visual.current_clip==({3:"Jump",4:"Roll",7:"Hit"}[group]) and not visual.dead,"Distributed breach/hurt category stays alive")
	var corpses=preload("res://Presentation/CorpseModels.gd");var posed:=corpses.posed(151);var corpse: Node3D=corpses.freeze(posed)
	check(corpse!=null and corpse.get_meta("corpse_body")==151 and corpse.find_children("*","Skeleton3D",true,false).is_empty(),"Matching static cadaver loads without private artwork")
	posed.queue_free();if corpse:corpse.free()
	actor.queue_free();for frame in 2:await process_frame
	print("DOLPHIN DISTRIBUTION: ",checks-failures," / ",checks);quit(1 if failures else 0)
