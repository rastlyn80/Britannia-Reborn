extends RefCounted

static func retarget(source: Animation, source_rig: Skeleton3D, target_rig: Skeleton3D) -> Animation:
	var result: Animation = source.duplicate(true)
	for track in result.get_track_count():
		var path := result.track_get_path(track)
		if path.get_subname_count() == 0: continue
		var bone := str(path.get_subname(0))
		var from := source_rig.find_bone(bone)
		var to := target_rig.find_bone(bone)
		if from < 0 or to < 0: continue
		var source_rest := source_rig.get_bone_rest(from)
		var target_rest := target_rig.get_bone_rest(to)
		var correction := target_rest.basis * source_rest.basis.inverse()
		for key in result.track_get_key_count(track):
			var value: Variant = result.track_get_key_value(track,key)
			match result.track_get_type(track):
				Animation.TYPE_POSITION_3D:
					var ratio := target_rest.origin.length()/maxf(source_rest.origin.length(),0.001)
					result.track_set_key_value(track,key,target_rest.origin+correction*(value-source_rest.origin)*ratio)
				Animation.TYPE_ROTATION_3D:
					result.track_set_key_value(track,key,(correction.get_rotation_quaternion()*value).normalized())
	return result
