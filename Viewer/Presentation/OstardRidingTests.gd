extends SceneTree
const Avatar=preload("res://Presentation/HumanAvatar.gd")
const Mounts=preload("res://Presentation/MountVisual.gd")
var checks:=0
var failures:=0
var rows: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;if failures<12:push_error(label)
func run() -> void:
	for body in [0xd2,0xda,0xdb,0x84,0xdc,0x124]:
		var loose:=Avatar.new();loose.initial_body=body;root.add_child(loose);loose.set_physics_process(false)
		loose.apply_server_appearance({"body":body,"hue":53},[])
		check(loose.horse_visual!=null and loose.horse_visual.kind==Mounts.kind(body) and loose.human_visual==null,"Native loose ostard selects its own source mesh")
		loose.animate(true,.3,.1,1.8);check(loose.horse_visual.current_clip=="Walk","Native movement uses source gait")
		loose.free()
	for female in [false,true]:
		var actor:=Avatar.new();actor.initial_body=401 if female else 400;root.add_child(actor);actor.set_physics_process(false)
		for item in [0x3ea3,0x3ea4,0x3ea5,0x3eac,0x3ead,0x3ea6,0x3eab,0x3ebb,0x3e9f]:
			for outfit in [[],[{"id":0x1f03},{"id":0x1539},{"id":0x170b}],[{"id":0x1415},{"id":0x1410},{"id":0x1411},{"id":0x1414},{"id":0x170b}]]:
				var worn: Array=outfit.duplicate(true);worn.append({"id":item,"layer":25,"hue":0x4001 if item==0x3eac else 53})
				actor.apply_server_appearance({"body":actor.initial_body,"hue":1002},worn)
				check(actor.horse_visual!=null and actor.human_visual.mounted_live_enabled and actor.horse_visual.native_mount_item==item,"Native layer 25 dispatches exact mount identity")
				actor.rider_contact.begin_mount(false);actor.human_visual.set_process(false)
				for pair in [["Rider_Idle","Idle"],["Rider_Walk","Walk"],["Rider_Run","Run"],["Rider_Attack","Idle"],["Rider_Bow","Idle"],["Rider_Crossbow","Idle"]]:
					actor.human_visual.cancel_action();actor.human_visual.play(pair[0],0.)
					var clip: String=pair[1] if item not in [0x3e9f,0x3ebb] else {"Idle":"idle","Walk":"walk","Run":"gallop"}[pair[1]]
					actor.horse_visual.animator.play(clip,0.)
					for phase in [0.,.25,.5,.75]:
						actor.animator.seek(actor.animator.current_animation_length*phase,true);actor.animator.pause();actor.horse_visual.animator.seek(actor.horse_visual.animator.current_animation_length*phase,true);actor.horse_visual.animator.pause()
						for frame in 3:await process_frame
						var feet: Array=actor.rider_contact.stirrup_errors
						var good: bool=actor.rider_contact.seat_error<.002 and feet.size()==2 and feet[0]<.025 and feet[1]<.025
						check(good,"Rider seat/feet stay fitted: "+str([female,item,pair,phase,actor.rider_contact.seat_error,feet]))
						check(actor.transform.is_equal_approx(Transform3D.IDENTITY),"Presentation preserves authoritative actor root")
						rows.append({"female":female,"item":item,"outfit":outfit,"clip":pair[0],"phase":phase,"seat_m":actor.rider_contact.seat_error,"feet_m":feet.duplicate(),"passed":good})
				check(actor.human_visual.missing_art.is_empty(),"Riding garments remain prepared")
				for heading in [.8,PI/2.]:
					actor.rotation.y=heading
					actor.human_visual.cancel_action();actor.human_visual.play("Rider_Idle",0.)
					actor.horse_visual.animator.play("idle" if item in [0x3e9f,0x3ebb] else "Idle",0.)
					actor.animator.seek(.1,true);actor.animator.pause();actor.horse_visual.animator.seek(.1,true);actor.horse_visual.animator.pause()
					for frame in 3:await process_frame
					check(actor.human_visual.global_basis.z.dot(actor.horse_visual.global_basis.z)>.85,"Rider facing turns with the creature")
					check(actor.rider_contact.seat_error<.002,"Turned rider retains saddle contact")
				actor.rotation.y=0.
		actor.free()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../outputs/ostard-riding"))
	var file:=FileAccess.open("res://../outputs/ostard-riding/contact.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"poses":rows,"scope":"Offline actual server-appearance avatar routing and animated rider bones; no live world-entry claim."},"\t"));file.close()
	print("OSTARD RIDING: ",checks-failures," / ",checks,"; ",rows.size()," poses");quit(1 if failures else 0)
