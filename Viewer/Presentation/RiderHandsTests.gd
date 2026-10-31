extends SceneTree
## Real rider rig measurements and optional close-up renders, not native riding permission.
var checks:=0
var failures:=0
var capture_frames:=false
var viewport: SubViewport
var camera: Camera3D
var fitted_hands: Dictionary={}
func _initialize() -> void:
	capture_frames="--capture" in OS.get_cmdline_user_args();call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func hand_metrics(visual: Node3D,side: String) -> Dictionary:
	var rig: Skeleton3D=visual.skeleton
	var wrist:=rig.get_bone_global_pose(rig.find_bone("hand_"+side)).origin
	var forearm:=rig.get_bone_global_pose(rig.find_bone("lowerarm_"+side)).origin
	var middle:=rig.get_bone_global_pose(rig.find_bone("middle_01_"+side)).origin
	var index:=rig.get_bone_global_pose(rig.find_bone("index_01_"+side)).origin
	var pinky:=rig.get_bone_global_pose(rig.find_bone("pinky_01_"+side)).origin
	var arm: Vector3=(rig.global_basis*(wrist-forearm)).normalized()
	var palm: Vector3=(rig.global_basis*(middle-wrist)).normalized()
	var thumb: Vector3=(rig.global_basis*(index-pinky)).normalized()
	var thumb_tip:=rig.get_bone_global_pose(rig.find_bone("thumb_03_"+side)).origin
	var index_joint:=rig.get_bone_global_pose(rig.find_bone("index_02_"+side)).origin
	var rein: bool=visual.grip.left_reins_holding if side=="l" else visual.grip.reins_holding
	return {"wrist_flexion_degrees":rad_to_deg(acos(clampf(arm.dot(palm),-1.,1.))),"thumb_up_dot":thumb.dot(Vector3.UP),"thumb_contact_m":thumb_tip.distance_to(index_joint),"rein":rein}
func run() -> void:
	viewport=SubViewport.new();viewport.size=Vector2i(960,960);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	preload("res://Presentation/ItemStudio.gd").studio_lights(viewport)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=1.45;viewport.add_child(camera);camera.position=Vector3(2.,2.75,4.6);camera.look_at(Vector3(0,2.36,0))
	var folder:=ProjectSettings.globalize_path("res://../outputs/rider-hands");DirAccess.make_dir_recursive_absolute(folder)
	var samples: Array=[]
	for female in [false,true]:
		for pair in [[0x3e9f,"robe"],[0x3e9f,"armour"],[0x3e9f,"sword"],[0x3e9f,"shield"],[0x3e9f,"bow"],[0x3e9f,"crossbow"],[0x3ea3,"robe"],[0x3ea6,"robe"],[0x3ead,"robe"]]:
			var mount: int=pair[0];var outfit: String=pair[1]
			var actor:=preload("res://Presentation/HumanAvatar.gd").new();actor.initial_body=401 if female else 400;viewport.add_child(actor);actor.set_physics_process(false)
			var worn: Array=[{"id":mount,"layer":25}]
			if outfit=="robe":worn.append({"id":0x1f03,"hue":1109})
			elif outfit=="armour":worn.append_array([{"id":0x1415},{"id":0x1410},{"id":0x1414},{"id":0x1411},{"id":0x170b}])
			if outfit in ["sword","shield","bow","crossbow"]:worn.append_array([{"id":0x1517},{"id":0x1539},{"id":{"sword":0x13ff,"shield":0x1b76,"bow":0x13b1,"crossbow":0x0f4f}[outfit]}])
			actor.apply_server_appearance({"body":actor.initial_body,"hue":1002},worn);actor.rider_contact.begin_mount(false)
			actor.rider_contact.modification_processed.connect(func():
				for side in ["l","r"]:fitted_hands[side]=hand_metrics(actor.human_visual,side))
			for speed in [0.,1.8,4.88,9.75]:
				for phase in [.05,.35,.65,.95]:
					actor.animate(speed>0.,0.,1./60.,speed)
					actor.human_visual.animator.seek(actor.human_visual.animator.current_animation_length*phase,true);actor.human_visual.animator.pause()
					actor.horse_visual.animator.seek(actor.horse_visual.animator.current_animation_length*phase,true);actor.horse_visual.animator.pause()
					for frame in 3:await process_frame
					for side in ["l","r"]:
						var metrics: Dictionary=fitted_hands[side].duplicate()
						if metrics.rein:
							check(float(metrics.wrist_flexion_degrees)<25.,"Rein wrist stays aligned with forearm")
							check(float(metrics.thumb_up_dot)>.55,"Rein grip has a natural thumb-up orientation")
						check(bool(metrics.rein)==(side=="l" if outfit=="sword" else side=="r" if outfit in ["shield","bow"] else false if outfit=="crossbow" else true),"Only the free hand takes a rein grip")
						if metrics.rein:check(float(metrics.thumb_contact_m)<.035,"Thumb closes across the index finger")
						metrics.merge({"mount":mount,"female":female,"outfit":outfit,"speed":speed,"phase":phase,"side":side});samples.append(metrics)
					check(actor.rider_contact.seat_error<.003 and actor.rider_contact.stirrup_errors.all(func(error: float):return error<.03),"Hand fitting preserves saddle/stirrup contact")
					check(actor.transform.is_equal_approx(Transform3D.IDENTITY),"Hand fitting does not move the native avatar root")
					if capture_frames and mount==0x3e9f and outfit in ["robe","armour"] and phase==.35 and speed in [0.,1.8]:
						await RenderingServer.frame_post_draw
						var name:="%s-%s-%s-%s.png"%["after","female" if female else "male",outfit,"idle" if speed==0. else "walk"]
						viewport.get_texture().get_image().save_png(folder.path_join(name))
			actor.apply_server_appearance({"body":actor.initial_body,"hue":1002},worn.filter(func(item: Dictionary):return int(item.get("layer",0))!=25))
			actor._finish_dismount()
			check(not actor.human_visual.grip.reins_holding and not actor.human_visual.grip.left_reins_holding,"Dismount clears rein-specific fingers")
			actor.free()
	var file:=FileAccess.open(folder.path_join("validation.json"),FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":samples,"scope":"Actual rider wrist axes and thumb orientation across both genders, robes/armour, four gaits, four mount rigs, weapons/shields and dismount cleanup. Samples are captured during modification_processed, before Godot restores the animation pose. Offline skin/rig and render review; native mounting permissions remain separate."},"\t"));file.close()
	print("RIDER HANDS: ",checks-failures," / ",checks,"; ",samples.size()," hand samples");quit(1 if failures else 0)
