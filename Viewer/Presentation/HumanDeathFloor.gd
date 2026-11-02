extends RefCounted
## Offline-grounded death on the exact licensed body/rig/motion, export-safe.
const VERSION:=2
static var fingerprints: Dictionary={}
static var clips: Dictionary={}
static func relative_rig(human: Node3D) -> Transform3D:
	# Compose local transforms: world translation/facing must not alter a digest
	# through floating-point cancellation at distant native coordinates.
	var node: Node3D=human.skeleton;var transform:=Transform3D.IDENTITY
	while node!=human:
		transform=node.transform*transform;node=node.get_parent() as Node3D
		assert(node!=null,"Human rig must belong to its visual")
	return transform
static func signature(human: Node3D,animation: Animation) -> String:
	var mesh: MeshInstance3D=human.model.find_children("Body*","MeshInstance3D",true,false)[0]
	var rig: Skeleton3D=human.skeleton;var rest: Array=[]
	for bone in rig.get_bone_count():rest.append([rig.get_bone_name(bone),rig.get_bone_parent(bone),rig.get_bone_global_rest(bone)])
	var context:=HashingContext.new();context.start(HashingContext.HASH_SHA256)
	context.update(var_to_bytes([human.female,rest,relative_rig(human)]))
	var key:=str(mesh.mesh.get_instance_id())+":"+str(mesh.skin.get_instance_id())+":"+str(animation.get_instance_id())+":"+context.finish().hex_encode()
	if fingerprints.has(key):return fingerprints[key].digest
	var data: Array=[VERSION,human.female,rest,relative_rig(human),animation.length,animation.loop_mode]
	for surface in mesh.mesh.get_surface_count():
		var arrays:=mesh.mesh.surface_get_arrays(surface)
		data.append([arrays[Mesh.ARRAY_VERTEX],arrays[Mesh.ARRAY_BONES],arrays[Mesh.ARRAY_WEIGHTS]])
	for bind in mesh.skin.get_bind_count():data.append([mesh.skin.get_bind_bone(bind),str(mesh.skin.get_bind_name(bind)),mesh.skin.get_bind_pose(bind)])
	for track in animation.get_track_count():
		var keys: Array=[]
		for index in animation.track_get_key_count(track):keys.append([animation.track_get_key_time(track,index),animation.track_get_key_value(track,index),animation.track_get_key_transition(track,index)])
		data.append([animation.track_get_type(track),str(animation.track_get_path(track)),animation.track_get_interpolation_type(track),animation.track_get_interpolation_loop_wrap(track),animation.track_is_enabled(track),keys])
	context.start(HashingContext.HASH_SHA256);context.update(var_to_bytes(data));var digest:=context.finish().hex_encode()
	fingerprints[key]={"digest":digest,"mesh":mesh.mesh,"skin":mesh.skin,"animation":animation}
	return digest
static func install(human: Node3D) -> bool:
	var path:="res://local-art/human-npcs/shared/"+("female" if human.female else "male")+"-grounded-death.res"
	if not ResourceLoader.exists(path) or not human.animator.has_animation("Death"):return false
	var original: Animation=human.animator.get_animation("Death")
	var digest:=signature(human,original);var key:=path+":"+digest
	if not clips.has(key):
		var candidate:=ResourceLoader.load(path,"Animation",ResourceLoader.CACHE_MODE_IGNORE) as Animation
		if candidate==null or int(candidate.get_meta("human_death_floor_version",0))!=VERSION or str(candidate.get_meta("human_death_source_signature",""))!=digest:return false
		clips[key]=candidate
	var library: AnimationLibrary=human.animator.get_animation_library("").duplicate()
	human.animator.stop(true);human.animator.remove_animation_library("");human.animator.add_animation_library("",library)
	library.remove_animation("Death");library.add_animation("Death",clips[key]);human.set_meta("grounded_death_signature",digest)
	return true
