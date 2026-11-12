extends SceneTree
## Independent semantic checks against pinned server weapon/dolphin behaviour.
class Probe extends "res://Presentation/CreatureVisual.gd":
	func _ready() -> void:pass
class ProbeAvatar extends Node3D:
	var horse_visual: Node3D
	func receive_native_action(request: Dictionary) -> bool:
		return horse_visual.receive_action(request)

const ApproachActions := preload("res://Presentation/CreatureApproachActions.gd")
const NativeActions := preload("res://Presentation/NativeMobileActions.gd")
const Appearance := preload("res://Network/MobileAppearance.gd")
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
	check_colossal_blow(actor)
	check_monster_approach(actor, library)
	actor.entry={};actor.animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for profile in ["animal","sea","monster"]:
		actor.action_profile=profile
		for rate in [.25,1.,3.2]:
			for protocol in ["classic","new"]:
				var request: Dictionary={"protocol":"classic","action":4 if profile=="monster" else 5,"frames":5,"delay":0} if protocol=="classic" else {"protocol":"new","type":0}
				for repetition in 2:
					actor.dead=false;actor.animator.speed_scale=rate
					check(actor.receive_action(request),"Repeated actual attack packet remains a supported native category")
					var seconds:=.8 if protocol=="classic" else 1.
					actor.animator.advance(seconds*.5)
					check(absf(actor.animator.current_animation_position-.5)<.001,"Each new native action restarts its timeline independently of the previous phase/rate: %s/%s/%s/%s"%[profile,protocol,rate,repetition])
	actor.contact.free();actor.free();print("CREATURE ACTION ROUTING: ",checks-failures," / ",checks);quit(1 if failures else 0)

func check_colossal_blow(actor: Probe) -> void:
	var avatar := ProbeAvatar.new()
	avatar.horse_visual = actor
	actor.entry = {}
	actor.native_body = 17
	var request := Appearance.action(PackedByteArray([0x6e, 0, 0, 0, 3, 0, 21, 0, 6, 0, 1, 0, 0, 0]))
	request["body"] = actor.native_body
	for profile in ["animal", "sea", "monster"]:
		actor.action_profile = profile
		actor.dead = false
		check(NativeActions.dispatch(avatar, request) and actor.current_clip == "Hit" and not actor.dead,
			"Colossal Blow plays a live reaction for " + profile)
		check(actor.get_meta("native_action") == request and int(request.action) == 21, "Original stun packet stays intact")
	var ordinary_fall := request.duplicate()
	ordinary_fall["frames"] = 5
	check(NativeActions.dispatch(avatar, ordinary_fall) and actor.dead and actor.current_clip == "Death",
		"Ordinary monster group 21 still reaches its fall")
	avatar.free()


func check_monster_approach(actor: Probe, library: AnimationLibrary) -> void:
	var avatar := ProbeAvatar.new()
	avatar.horse_visual = actor
	var request := Appearance.action(PackedByteArray([0x6e, 0, 0, 0, 3, 0, 11, 0, 5, 0, 1, 0, 0, 1]))
	actor.entry = {}
	actor.action_profile = "monster"
	actor.dead = false
	for body: int in [8, 22, 49, 66, 89, 94, 106, 107, 108, 109, 110, 111, 112, 113, 129, 135, 142, 147, 166, 168, 180, 206, 215, 790]:
		actor.native_body = body
		request["body"] = body
		check(ApproachActions.dispatch(avatar, request, false, -1) and actor.current_clip == "Fidget",
			"Native approach uses the retained alert on body %d" % body)
		check(actor.get_meta("native_action") == request, "Original approach packet stays intact")
		var other := request.merged({"delay": 0}, true)
		check(not ApproachActions.dispatch(avatar, other, false, -1), "A generic missing group 11 stays unsupported")
	actor.native_body = 17
	request["body"] = 17
	check(not ApproachActions.dispatch(avatar, request, false, -1), "Unreviewed bodies keep their existing routing")
	var source_notice := Animation.new()
	source_notice.length = 1.
	library.add_animation("SourceNotice", source_notice)
	actor.native_body = 22
	request["body"] = 22
	actor.entry = {"classic_action_categories": {"11": "SourceNotice"}}
	check(ApproachActions.dispatch(avatar, request, false, -1) and actor.current_clip == "SourceNotice",
		"An explicit available group 11 takes priority")
	avatar.free()
