extends RefCounted
## Prepared CC0 motion on the exact body rig, including garment-only controls.
static var prepared := {}
static func install(visual: Node3D, motion_folder: String = "") -> Dictionary:
	if motion_folder.is_empty():motion_folder=visual.folder+"/motion"
	var path: String=motion_folder+"/human-motion.glb"
	if not ResourceLoader.exists(path): return {}
	var destination: String=str(visual.animator.get_node(visual.animator.root_node).get_path_to(visual.skeleton))
	var key: String=motion_folder+"|"+destination
	if prepared.has(key):
		visual.animator.stop();visual.animator.remove_animation_library("");visual.animator.add_animation_library("",prepared[key].library)
		return prepared[key].metadata.duplicate(true)
	var metadata: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(motion_folder+"/motion.json"))
	var source: Node3D=load(path).instantiate()
	var rig: Skeleton3D=source.find_children("*","Skeleton3D",true,false)[0]
	var player: AnimationPlayer=source.find_children("*","AnimationPlayer",true,false)[0]
	for name in metadata.clips:
		if not player.has_animation(name):
			push_warning("Human motion is being rebuilt or needs reimport; using the previous gait")
			source.free();return {}
	var library: AnimationLibrary=visual.animator.get_animation_library("").duplicate()
	visual.animator.stop()
	visual.animator.remove_animation_library("")
	visual.animator.add_animation_library("",library)
	for name in metadata.clips:
		var clip: Animation=player.get_animation(name).duplicate(true)
		for track in range(clip.get_track_count()-1,-1,-1):
			var path_track:=clip.track_get_path(track)
			if path_track.get_subname_count()==0:
				clip.remove_track(track);continue
			var bone:=str(path_track.get_subname(0))
			var index: int=visual.skeleton.find_bone(bone)
			assert(index>=0,"Prepared human motion references an unknown bone")
			assert(visual.skeleton.get_bone_rest(index).is_equal_approx(rig.get_bone_rest(rig.find_bone(bone))),"Prepared motion bind pose changed")
			clip.track_set_path(track,NodePath(str(visual.animator.get_node(visual.animator.root_node).get_path_to(visual.skeleton))+":"+bone))
		clip.loop_mode=Animation.LOOP_LINEAR if metadata.clips[name].loop else Animation.LOOP_NONE
		if library.has_animation(name):library.remove_animation(name)
		library.add_animation(name,clip)
	source.free()
	prepared[key]={"library":library,"metadata":metadata}
	return metadata
