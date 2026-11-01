extends SceneTree
## Independent semantic checks against pinned server weapon/dolphin behaviour.
class Probe extends "res://Presentation/CreatureVisual.gd":
	func _ready() -> void:pass
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func run() -> void:
	var actor:=Probe.new();actor.set_process(false);actor.set_physics_process(false)
	actor.animator=AnimationPlayer.new();actor.add_child(actor.animator)
	var library:=AnimationLibrary.new();actor.animator.add_animation_library("",library)
	for name in ["Walk","Run","Idle","Eat","Alert","Attack","Attack2","Attack3","Hit","Death","Death2","Fidget","Fidget2","Jump","Roll","LieDown","Cast","AttackBow"]:
		var animation:=Animation.new();animation.length=1.;library.add_animation(name,animation)
	actor.contact=preload("res://Presentation/SourceMountContact.gd").new();root.add_child(actor)
	for profile in ["animal","sea","monster"]:
		actor.action_profile=profile;actor.dead=false
		check(actor.receive_action({"protocol":"classic","action":7 if profile!="monster" else 10}) and actor.current_clip=="Hit" and not actor.dead,"Pinned BaseWeapon classic hit is a live reaction: "+profile)
	actor.action_profile="monster";actor.dead=false
	check(actor.receive_action({"protocol":"classic","action":7}) and actor.current_clip=="AttackBow","Monster slot7 remains weapon-specific")
	actor.action_profile="sea";actor.entry={"new_action_categories":{"11":"Attack"}}
	for group in [3,4]:
		actor.dead=false;check(actor.receive_action({"protocol":"classic","action":group}) and actor.current_clip==("Fidget" if group==3 else "Fidget2") and not actor.dead,"Sea fidget is distinct from animal feeding")
	actor.dead=false;check(actor.receive_action({"protocol":"classic","action":12}) and actor.current_clip=="Attack" and not actor.dead,"Sea classic12 follows the comparison client's attack compatibility route")
	check(actor.receive_action({"protocol":"new","type":11}) and actor.current_clip=="Attack","Sea modern11 is an attack compatibility category")
	check(actor.receive_action({"protocol":"new","type":0,"mode":1}) and actor.current_clip=="Attack2","Sea modern attack preserves odd-mode alternative")
	actor.entry.classic_action_categories={"3":"Jump","4":"Roll"}
	for group in [3,4]:
		actor.dead=false;check(actor.receive_action({"protocol":"classic","action":group}) and actor.current_clip==("Jump" if group==3 else "Roll") and not actor.dead,"Native dolphin breach is a live explicit category")
	check(not actor.receive_action({"protocol":"classic","action":11}),"Sea creatures do not acquire an animal lying pose from slot11")
	actor.dead=false;check(actor.receive_action({"protocol":"classic","action":8}) and actor.dead and actor.current_clip=="Death","Native sea death8 still reaches death")
	actor.contact.free();actor.free();print("CREATURE ACTION ROUTING: ",checks-failures," / ",checks);quit(1 if failures else 0)
