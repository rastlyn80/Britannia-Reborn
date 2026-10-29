extends SceneTree
## Exercise prepared art, native actions, layers and grips on both real rigs.
const Visual=preload("res://Presentation/HumanVisual.gd")
const Wardrobe=preload("res://Presentation/HumanWardrobe.gd")
const Actions=preload("res://Presentation/HumanActions.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok:print("PASS ",label)
	else:failures+=1;push_error(label)
func fold_snapshot(actor: Node3D) -> Dictionary:
	var rig: Skeleton3D=actor.skeleton;var result:={}
	for side in ["l","r"]:
		var spans: Array=[]
		for finger in ["index","middle","ring","pinky"]:
			var points: Array[Vector3]=[]
			for segment in ["01","02","03"]:points.append(rig.get_bone_global_pose(rig.find_bone(finger+"_"+segment+"_"+side)).origin)
			var last:=rig.get_bone_global_pose(rig.find_bone(finger+"_03_"+side));points.append(last.origin+last.basis.y.normalized()*points[1].distance_to(points[2])*.65)
			var length:=0.
			for i in 3:length+=points[i].distance_to(points[i+1])
			spans.append(points[0].distance_to(points[-1])/length)
		result[side]=spans
	return result
func run() -> void:
	check(Actions.CLASSIC.size()==35,"all 35 classic categories have explicit human replacements")
	var unique:=[]
	for id: int in Wardrobe.Coverage.ITEMS:
		var entry: Array=Wardrobe.Coverage.ITEMS[id]
		if not unique.has(entry[1]):unique.append(entry[1])
	for female in [false,true]:
		var actor:=Visual.new();actor.female=female;root.add_child(actor);actor.set_process(false)
		for frame in 2:await process_frame
		var tag:="female" if female else "male"
		var rig: Skeleton3D=actor.skeleton
		var references:={}
		for bone in rig.get_bone_count():references[bone]=rig.get_bone_rest(bone)
		var ids:=0;var poses:=0;var bindings:=true;var finite:=true
		for id: int in Wardrobe.Coverage.ITEMS:
			actor.cancel_action();actor.set_equipment([{"id":id,"hue":1153}])
			check(actor.missing_art.is_empty() and actor.unsupported_items.is_empty(),tag+": prepared native wearable %04x retains ID/hue" % id)
			ids+=1
			await process_frame
		for asset in unique:
			var id:=0
			for candidate: int in Wardrobe.Coverage.ITEMS:
				if Wardrobe.Coverage.ITEMS[candidate][1]==asset:id=candidate;break
			actor.cancel_action();actor.set_equipment([{"id":id,"hue":1153}])
			for mesh: MeshInstance3D in actor.parts:
				for bind in mesh.skin.get_bind_count():bindings=bindings and rig.find_bone(mesh.skin.get_bind_name(bind))>=0
			for clip in ["Idle","Walk","Run","Cast","Sword_A"]:
				actor.play(clip,0.)
				for phase in [.0,.25,.5,.75,1.]:
					actor.animator.seek(actor.animator.current_animation_length*phase,true)
					for bone in rig.get_bone_count():finite=finite and rig.get_bone_global_pose(bone).is_finite()
					poses+=1
			await process_frame
		check(bindings and finite,tag+": %d category assets / %d sampled poses retain named binds and finite joints" % [unique.size(),poses])
		actor.cancel_action();actor.set_equipment([])
		check(not actor.request_action({"body":401 if female else 400,"protocol":"classic","action":26}),tag+": deferred rider playback is disabled by default")
		actor.rider_preview_enabled=true
		for group in range(35):
			var request:={"body":401 if female else 400,"protocol":"classic","action":group,"frames":6,"delay":1,"repeat_count":1}
			var ok:=actor.request_action(request)
			check(ok and actor.action_clip==Actions.CLASSIC[group] and is_equal_approx(actor.action_duration,1.44),tag+": classic group %d routes with server timing" % group)
			if not ok:continue
			var animation: Animation=actor.animator.get_animation(actor.action_clip)
			for phase in [.0,.25,.5,.75,1.]:
				actor.animator.seek(animation.length*phase,true)
				var head:=rig.get_bone_global_pose(rig.find_bone("head")).origin
				check(head.is_finite() and head.length()<3.,tag+": group %d has bounded presentation at %.2f" % [group,phase])
			actor.cancel_action()
		check(actor.get_transform().is_equal_approx(Transform3D.IDENTITY),tag+": actions leave the authoritative mobile transform unchanged")
		var captured:={}
		var watcher:=func():captured.merge(fold_snapshot(actor),true)
		actor.grip.modification_processed.connect(watcher)
		for id in [0x13b1,0xf4f,0x1b74]:
			actor.set_equipment([{"id":id}]);actor.play(actor.stance_clip("Idle"),0.);actor.animator.seek(.2,true);actor.animator.pause();captured.clear()
			for frame in 3:await process_frame
			var side: String="r" if id==0xf4f else "l"
			var closed:=captured.has(side)
			for ratio in captured.get(side,[]):closed=closed and float(ratio)<.83
			check(closed,tag+": actual holding fingers close for native item %04x" % id)
		actor.grip.modification_processed.disconnect(watcher)
		for entry in [[0x13b1,"Bow_Idle","hand_l"],[0xf4f,"Crossbow_Idle","hand_r"],[0x13b1,"Bow_Attack","hand_l"],[0xf4f,"Crossbow_Attack","hand_r"]]:
			actor.cancel_action();actor.set_equipment([{"id":entry[0]}]);actor.play(entry[1],0.);actor.animator.seek(0.,true)
			var bone:=rig.find_bone(entry[2]);var orientation:=rig.get_bone_global_pose(bone).basis.get_rotation_quaternion();var maximum:=0.
			for phase in [.25,.5,.75,1.]:
				actor.animator.seek(actor.animator.current_animation_length*phase,true)
				maximum=maxf(maximum,orientation.angle_to(rig.get_bone_global_pose(bone).basis.get_rotation_quaternion()))
			check(maximum<.02,tag+": calibrated ranged wrist keeps prop orientation in "+str(entry[1]))

		actor.set_equipment([{"id":0x13b1}])
		check(actor.stance_clip("Idle")=="Bow_Idle" and actor.grip.left_holding,tag+": bow chooses a ranged stance and left holding hand")
		actor.set_equipment([{"id":0xf4f}])
		check(actor.stance_clip("Idle")=="Crossbow_Idle" and actor.grip.holding,tag+": crossbow chooses a ranged stance and right holding hand")
		actor.set_equipment([{"id":0x1415},{"id":0x1517},{"id":0x1411},{"id":0x1539},{"id":0x1b74}])
		var layered:=Wardrobe.resolve(actor.server_equipment)
		check(not layered.pieces.has("shirt") and not (int(layered.bits)&3) and layered.pieces.has("shield"),tag+": armour replaces covered underlayers and shield keeps an independent slot")
		actor.set_equipment([{"id":0x1415,"hue":1153},{"id":0x1410,"hue":1153},{"id":0x1411,"hue":1153},{"id":0x1414},{"id":0x170b}])
		check(actor.parts.any(func(p: MeshInstance3D):return p.name.begins_with("Extra_armour_undercoat")) and actor.parts.any(func(p: MeshInstance3D):return p.name.begins_with("Extra_armour_boots")),tag+": armour retains a separate undercoat and boots fitted beneath greaves")
		check((int(actor.get_meta("body_mask_bits"))&2)!=0,tag+": complete armour trousers use their matching leg mask")
		var steel:=0;var lining:=0;var proper_materials:=true
		for part: MeshInstance3D in actor.parts:
			for surface in part.mesh.get_surface_count():
				var material:=part.mesh.surface_get_material(surface) as StandardMaterial3D
				if material==null:continue
				if material.resource_name.begins_with("Armour_steel"):
					steel+=1;proper_materials=proper_materials and material.metallic>.8 and material.roughness>=.4
					var dyed:=part.get_active_material(surface) as ShaderMaterial
					proper_materials=proper_materials and dyed!=null and float(dyed.get_shader_parameter("metalness"))>.8 and float(dyed.get_shader_parameter("roughness"))>=.4
				elif material.resource_name.begins_with("Armour_Lining"):
					lining+=1;proper_materials=proper_materials and material.metallic<.01 and material.roughness>.8 and part.get_surface_override_material(surface)==null
		check(steel>0 and lining>0 and proper_materials,tag+": native steel dyes retain metallic roughness and never whiten textile backing")
		actor.set_equipment([{"id":0x203c,"layer":11},{"id":0x1415},{"id":0x1515}])
		check(actor.parts.any(func(p: MeshInstance3D):return p.name.begins_with("Extra_hair_long_layered_cloak")),tag+": long hair retains the fitted cloak layer with armour")
		actor.free()
		var avatar:=preload("res://Presentation/HumanAvatar.gd").new();avatar.initial_body=401 if female else 400;root.add_child(avatar)
		avatar.apply_server_appearance({"body":401 if female else 400,"hue":1002},[{"id":0x3e9f,"layer":25}])
		var supported: bool=preload("res://Presentation/HorseVisual.gd").available()
		check(avatar.receive_native_action({"body":401 if female else 400,"protocol":"classic","action":26})==supported,tag+": mounted actions require available horse art and a supported mount")
		avatar.human_visual.cancel_action()
		avatar.animate(true,0.,.05,2.44)
		check(avatar.human_visual.current_clip.begins_with("Rider_")==supported and avatar.foot_contact.grounded!=supported,tag+": available horse enables seated playback and suppresses ground feet")
		avatar.human_visual.rider_preview_enabled=true
		avatar.animate(true,0.,.05,2.44)
		check(avatar.human_visual.current_clip=="Rider_Walk" and not avatar.foot_contact.grounded,tag+": mounted presentation routes rider gait without dragging seated feet to ground")
		check(avatar.receive_native_action({"body":401 if female else 400,"protocol":"classic","action":26}),tag+": rider attack reaches the real avatar controller")
		check(avatar.receive_native_action({"body":401 if female else 400,"protocol":"classic","action":9}) and avatar.human_visual.action_clip=="Rider_Attack",tag+": a mounted native attack selects its seated replacement")
		avatar.free()
	print("HUMAN COVERAGE: ",checks-failures," passed / ",checks," total")
	quit(1 if failures else 0)
