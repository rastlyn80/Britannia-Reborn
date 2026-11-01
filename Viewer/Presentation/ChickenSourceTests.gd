extends SceneTree
func _initialize() -> void:call_deferred("run")
func vertices(mesh: MeshInstance3D,rig: Skeleton3D) -> Array:
	var matrices: Array[Transform3D]=[]
	for i in mesh.skin.get_bind_count():
		var bone:=mesh.skin.get_bind_bone(i)
		if bone<0:bone=rig.find_bone(mesh.skin.get_bind_name(i))
		matrices.append(rig.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(i))
	var result: Array=[]
	for surface in mesh.mesh.get_surface_count():
		var a:=mesh.mesh.surface_get_arrays(surface);var v: PackedVector3Array=a[Mesh.ARRAY_VERTEX];var b: PackedInt32Array=a[Mesh.ARRAY_BONES];var w: PackedFloat32Array=a[Mesh.ARRAY_WEIGHTS];var stride:=b.size()/v.size()
		for i in v.size():
			var point:=Vector3.ZERO
			for j in stride:point+=(matrices[b[i*stride+j]]*v[i])*w[i*stride+j]
			point=rig.to_global(point);result.append([point.x,point.y,point.z])
	return result
func run() -> void:
	var actor:=load("res://local-art/chicken/chicken-modern.glb").instantiate() as Node3D;root.add_child(actor);var rig:=actor.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D;var player:=actor.find_children("*","AnimationPlayer",true,false)[0] as AnimationPlayer;var meshes:=actor.find_children("*","MeshInstance3D",true,false);var rows: Array=[];var failures:=0
	for clip in player.get_animation_list():
		if not str(clip).begins_with("Source"):continue
		for step in 17:
			player.play(clip,0.);player.seek(player.get_animation(clip).length*float(step)/16.,true);player.pause();rig.force_update_all_bone_transforms();var points: Array=[];var floor_y:=INF
			for mesh: MeshInstance3D in meshes:points.append_array(vertices(mesh,rig))
			for point in points:
				var p:=Vector3(point[0],point[1],point[2]);floor_y=min(floor_y,p.y)
				if not p.is_finite():failures+=1
			var bones: Dictionary={}
			for i in rig.get_bone_count():
				var p:=rig.to_global(rig.get_bone_global_pose(i).origin);bones[rig.get_bone_name(i)]=[p.x,p.y,p.z]
			rows.append({"clip":str(clip).trim_prefix("Source"),"phase":float(step)/16.,"floor_y":floor_y,"points":points,"bones":bones})
	FileAccess.open("res://../outputs/creatures/chicken-trial/source-skins.json",FileAccess.WRITE).store_string(JSON.stringify({"asset_sha256":FileAccess.get_sha256("res://local-art/chicken/chicken-modern.glb"),"import_sha256":FileAccess.get_sha256("res://local-art/chicken/chicken-modern.glb.import"),"test_sha256":FileAccess.get_sha256(get_script().resource_path),"bones":rig.get_bone_count(),"meshes":meshes.size(),"failures":failures,"samples":rows}));print("PRIVATE BAKED CHICKEN: ",rows.size()," skins / ",failures," nonfinite points");actor.free();quit(1 if failures else 0)
