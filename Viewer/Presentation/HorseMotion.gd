extends RefCounted
## Authored additions on the licensed rig. Source clips remain unchanged.
static func install(player: AnimationPlayer,rig: Skeleton3D) -> void:
	var library:=player.get_animation_library("")
	var source:=player.get_animation("canter")
	var fast:=Animation.new();fast.length=.64;fast.loop_mode=Animation.LOOP_LINEAR
	# Re-phase each leg chain, separating the source canter's paired contacts.
	# This is a canter-derived authored fast gait, not a new captured animation.
	for track in source.get_track_count():
		var kind:=source.track_get_type(track)
		if kind not in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D,Animation.TYPE_SCALE_3D]:continue
		var target:=fast.add_track(kind);var path:=source.track_get_path(track);fast.track_set_path(target,path)
		var bone:=str(path.get_subname(0)) if path.get_subname_count() else ""
		var offset:=0.
		if bone in ["upperarm_L","forearm_L","hand_L","finger_L"]:offset=-.07
		elif bone in ["upperarm_R","forearm_R","hand_R","finger_R"]:offset=.07
		elif bone in ["thigh_L","calf_L","foot_L","toe_L"]:offset=.04
		elif bone in ["thigh_R","calf_R","foot_R","toe_R"]:offset=-.04
		for frame in 33:
			var phase:=float(frame)/32.;var time:=fposmod(phase+offset,1.)*source.length
			if kind==Animation.TYPE_ROTATION_3D:fast.rotation_track_insert_key(target,phase*fast.length,source.rotation_track_interpolate(track,time))
			elif kind==Animation.TYPE_SCALE_3D:fast.scale_track_insert_key(target,phase*fast.length,source.scale_track_interpolate(track,time))
			else:
				var p:=source.position_track_interpolate(track,time)
				if bone=="root":p.y+=.045*pow(maxf(0.,sin(TAU*(phase-.12))),2.)
				fast.position_track_insert_key(target,phase*fast.length,p)
	library.add_animation("gallop",fast)
	for name in ["hit","death"]:
		var clip:=Animation.new();clip.length=.52 if name=="hit" else 1.8
		var idle:=player.get_animation("idle")
		for track in idle.get_track_count():
			var kind:=idle.track_get_type(track)
			if kind not in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D,Animation.TYPE_SCALE_3D]:continue
			var target:=clip.add_track(kind);var path:=idle.track_get_path(track);clip.track_set_path(target,path)
			var bone:=str(path.get_subname(0)) if path.get_subname_count() else ""
			for frame in 25:
				var u:=float(frame)/24.;var weight:=sin(PI*u) if name=="hit" else smoothstep(.08,.9,u)
				if kind==Animation.TYPE_POSITION_3D:
					var p:=idle.position_track_interpolate(track,0.)
					if bone=="root":
						if name=="hit":p.y-=weight*.035;p.z-=weight*.045
						else:p+=Vector3(-1.18*sin(weight*1.48),1.18*(1.-cos(weight*1.48))-.72*weight,0.)
					clip.position_track_insert_key(target,u*clip.length,p)
				elif kind==Animation.TYPE_ROTATION_3D:
					var q:=idle.rotation_track_interpolate(track,0.);var index:=rig.find_bone(bone)
					var angle:=0.;var axis:=Vector3.RIGHT
					if name=="death":
						if bone=="root":angle=weight*1.48;axis=Vector3.FORWARD
						elif bone.begins_with("forearm") or bone.begins_with("calf"):angle=weight*.65
						elif bone.begins_with("neck"):angle=weight*.12
					elif bone.begins_with("neck"):angle=-weight*.09
					elif bone=="head":angle=weight*.12
					if index>=0 and angle!=0.:
						var rest:=rig.get_bone_global_rest(index).basis
						q=q*Quaternion((rest.inverse()*axis).normalized(),angle)
					clip.rotation_track_insert_key(target,u*clip.length,q)
				else:clip.scale_track_insert_key(target,u*clip.length,idle.scale_track_interpolate(track,0.))
		library.add_animation(name,clip)
