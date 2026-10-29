extends SceneTree
const Avatar=preload("res://Presentation/HumanAvatar.gd")
const Horse=preload("res://Presentation/HorseVisual.gd")
var checks:=0
var failures:=0
var samples: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func run() -> void:
	check(Horse.available(),"Pinned horse art is available")
	for body: int in Horse.BODIES:
		check(Horse.horse_body(Horse.BODIES[body])==body,"Native horse body/mount pair round-trips")
		var loose:=Avatar.new();loose.initial_body=body;root.add_child(loose);loose.set_physics_process(false)
		loose.apply_server_appearance({"body":body,"hue":1153},[])
		check(loose.human_visual==null and loose.horse_visual!=null and loose.horse_visual.native_hue==1153,"Unmounted horse never uses a humanoid fallback and retains hue")
		loose.animate(true,.5,.1,1.8);check(loose.horse_visual.current_clip=="walk","Loose horse has source locomotion")
		loose.free()
	for female in [false,true]:
		var actor:=Avatar.new();actor.initial_body=401 if female else 400;root.add_child(actor);actor.set_physics_process(false)
		for variant: int in Horse.BODIES:
			var mount:={"serial":0x40000001,"id":Horse.BODIES[variant],"layer":25,"hue":1153}
			for outfit in [[{"id":0x1517},{"id":0x1539},{"id":0x170b}],[{"id":0x1415},{"id":0x1410},{"id":0x1411},{"id":0x1414},{"id":0x170b}],[{"id":0x1f03},{"id":0x1539},{"id":0x170b}]]:
				var worn: Array=outfit.duplicate(true);worn.append(mount)
				actor.apply_server_appearance({"body":actor.initial_body,"hue":1002},worn)
				check(actor.human_visual.mounted_live_enabled and actor.horse_visual.native_body==variant,"Only a recognized server mount enables live riding")
				actor.rider_contact.seated_weight=1.
				for pair in [["Rider_Idle","idle",0.],["Rider_Walk","walk",1.8],["Rider_Run","canter",9.75],["Rider_Attack","canter",9.75],["Rider_Bow","idle",0.],["Rider_Crossbow","idle",0.],["Rider_Slap","idle",0.],["Rider_Idle","rear",0.]]:
					actor.animate(pair[2]>0.,0.,.1,pair[2]);actor.human_visual.cancel_action();actor.human_visual.play(pair[0],0.)
					actor.human_visual.set_process(false);actor.horse_visual.animator.play(pair[1],0.)
					for phase in [.0,.25,.5,.75]:
						actor.animator.seek(actor.animator.current_animation_length*phase,true);actor.animator.pause()
						actor.horse_visual.animator.seek(actor.horse_visual.animator.current_animation_length*phase,true);actor.horse_visual.animator.pause()
						for frame in 2:await process_frame
						var feet: Array=actor.rider_contact.stirrup_errors
						var contact: bool=actor.rider_contact.seat_error<.002 and feet.size()==2 and feet[0]<.025 and feet[1]<.025
						check(contact,"Animated saddle/stirrup contact on both bodies, all four horses, three outfits and rider actions")
						check(actor.transform.is_equal_approx(Transform3D.IDENTITY),"Mount animation leaves the authoritative avatar transform unchanged")
						check(actor.human_visual.missing_art.is_empty(),"Mounted clothing remains available")
						samples.append({"female":female,"body":variant,"rider_clip":pair[0],"horse_clip":pair[1],"phase":phase,"seat_error_m":actor.rider_contact.seat_error,"stirrup_errors_m":feet.duplicate(),"outfit":outfit,"passed":contact})
			for group in range(23,30):
				check(actor.receive_native_action({"body":actor.initial_body,"protocol":"classic","action":group,"frames":6,"delay":1}),"Seven classic mounted groups play with native timing")
				actor.animate(true,0.,.1,9.75)
				check(is_equal_approx(actor.human_visual.action_duration,1.44) and is_equal_approx(actor.animator.speed_scale,1.),"Mounted actions preserve server frame timing even while the horse canters faster")
			check(actor.receive_native_action({"body":actor.initial_body,"protocol":"new","type":0,"subaction":1}) and actor.human_visual.action_clip=="Rider_Bow","New protocol ranged attack selects its seated action")
		actor.apply_server_appearance({"body":actor.initial_body,"hue":1002},[])
		await create_timer(1.7).timeout
		check(actor.horse_visual==null and absf(actor.human_visual.position.y)<.001 and actor.ground_visual_offset.length()<1.,"Server unequip completes the leg-over dismount beside the horse without moving the authoritative root")
		actor.apply_server_appearance({"body":actor.initial_body},[{"id":0x3e90,"layer":25}])
		check(actor.horse_visual==null and not actor.human_visual.mounted_live_enabled and actor.has_meta("deferred_mount"),"Unknown/non-horse mount is explicit and never becomes a horse")
		actor.free()
	check(is_equal_approx(Horse.step_seconds([{"layer":25,"id":0x3e9f}],false),.2) and is_equal_approx(Horse.step_seconds([{"layer":25,"id":0x3e9f}],true),.1),"Mounted walk/run intervals match pinned ModernUO defaults")
	check(is_equal_approx(Horse.step_seconds([],false),.4) and is_equal_approx(Horse.step_seconds([],true),.2),"On-foot intervals retain native defaults")
	var actions=preload("res://Presentation/HumanActions.gd")
	check(actions.resolve({"body":400,"protocol":"new","type":4},true)=="" and actions.resolve({"body":400,"protocol":"new","type":11},true)=="" and actions.resolve({"body":400,"protocol":"classic","action":32},true)=="","Unsupported mounted hit/cast/bow gestures never play standing poses on the saddle")
	var file:=FileAccess.open("res://../outputs/horse-session/contact-validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":samples,"scope":"Actual post-animation saddle/stirrup fitting: both bodies, four horse identities, three outfits, seven human rider actions plus source rear, four phases. Seat <=2 mm, ankles <=25 mm. Not universal layered cloth/triangle collision."},"\t"));file.close()
	print("HORSE TESTS: ",checks-failures," / ",checks," passed; ",samples.size()," contact poses");quit(1 if failures else 0)
