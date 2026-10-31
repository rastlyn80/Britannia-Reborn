extends RefCounted
## Authored feeding on existing licensed/source rigs. Rest reuses the source
## collapse as a lying category; it is not a new captured/faithful native clip.
static func install(player: AnimationPlayer,rig: Skeleton3D,source_idle: String,source_death: String,eat_name: String,rest_name: String) -> void:
	var library:=player.get_animation_library("")
	if player.has_animation(eat_name):
		player.get_animation(eat_name).loop_mode=Animation.LOOP_NONE
		var rest: Animation=player.get_animation(source_death).duplicate(true);rest.loop_mode=Animation.LOOP_NONE
		library.add_animation(rest_name,rest)
		return
	var idle:=player.get_animation(source_idle)
	var neck_count:=0
	for i in rig.get_bone_count():
		if "neck" in rig.get_bone_name(i).to_lower():neck_count+=1
	var eat:=Animation.new();eat.length=2.4
	for track in idle.get_track_count():
		var type:=idle.track_get_type(track)
		if type not in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D,Animation.TYPE_SCALE_3D]:continue
		var target:=eat.add_track(type);var path:=idle.track_get_path(track);eat.track_set_path(target,path)
		var name:=str(path.get_subname(0)) if path.get_subname_count()>0 else ""
		var index:=rig.find_bone(name)
		for frame in 49:
			var u:=float(frame)/48.;var down:=smoothstep(0.,.25,u)*(1.-smoothstep(.75,1.,u))
			if type==Animation.TYPE_ROTATION_3D:
				var rotation:=idle.rotation_track_interpolate(track,0.)
				var angle:=0.
				if "neck" in name.to_lower():angle=down*.95/maxi(1,neck_count)
				elif "head" in name.to_lower():angle=down*(.18+.035*sin(TAU*u*8.))
				if angle!=0. and index>=0:
					var axis:=((rig.global_basis*rig.get_bone_global_rest(index).basis).inverse()*Vector3.RIGHT).normalized()
					rotation=rotation*Quaternion(axis,angle)
				eat.rotation_track_insert_key(target,u*eat.length,rotation)
			elif type==Animation.TYPE_POSITION_3D:eat.position_track_insert_key(target,u*eat.length,idle.position_track_interpolate(track,0.))
			else:eat.scale_track_insert_key(target,u*eat.length,idle.scale_track_interpolate(track,0.))
	library.add_animation(eat_name,eat)
	var rest: Animation=player.get_animation(source_death).duplicate(true);rest.loop_mode=Animation.LOOP_NONE
	library.add_animation(rest_name,rest)
