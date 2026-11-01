extends SceneTree
## Measure exported independent skin and cetacean paths before native install.
const Geometry=preload("res://Presentation/SkinGeometry.gd")
var asset_path:="res://local-art/dolphin/dolphin.glb"
var checks:=0
var failures:=0
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--asset="):asset_path=argument.trim_prefix("--asset=")
	call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func run() -> void:
	var model: Node3D=load(asset_path).instantiate();root.add_child(model)
	var rig: Skeleton3D=model.find_children("*","Skeleton3D",true,false)[0]
	var player: AnimationPlayer=model.find_children("*","AnimationPlayer",true,false)[0]
	var meshes:=model.find_children("*","MeshInstance3D",true,false)
	check(meshes.size()==6 and rig.get_bone_count()==9,"Licensed six-part mesh uses the nine authored bones")
	var rows: Array=[]
	for clip in ["Idle","Walk","Run","Attack","Attack2","Attack3","Hit","Death","Death2","Fidget","Fidget2","Jump","Roll","Cast"]:
		check(player.has_animation(clip),"Exported category exists: "+clip)
		if not player.has_animation(clip):continue
		player.get_animation(clip).loop_mode=Animation.LOOP_NONE
		var tail: Array[Vector3]=[];var body: Array[Vector3]=[];var head: Array[Vector3]=[]
		for sample in 9:
			var phase:=float(sample)/8.
			player.play(clip,0.);player.seek(player.get_animation(clip).length*phase,true);player.pause()
			for frame in 2:await process_frame
			var bounds:=AABB();var first:=true
			for mesh: MeshInstance3D in meshes:
				check(mesh.skin!=null,"All facial and body surfaces remain skinned")
				var box:=Geometry.deformed_bounds(mesh,rig)
				bounds=box if first else bounds.merge(box);first=false
			check(bounds.position.is_finite() and bounds.size.length()>2.5 and bounds.size.length()<5.,"Actual deformed geometry stays finite and bounded")
			check(model.global_transform.is_equal_approx(Transform3D.IDENTITY),"Animation never moves the entity anchor")
			tail.append(rig.to_global(rig.get_bone_global_pose(rig.find_bone("flukes")).origin))
			body.append(rig.to_global(rig.get_bone_global_pose(rig.find_bone("body")).origin))
			head.append(rig.to_global(rig.get_bone_global_pose(rig.find_bone("head")).origin))
			rows.append({"clip":clip,"phase":phase,"bounds":{"position":[bounds.position.x,bounds.position.y,bounds.position.z],"size":[bounds.size.x,bounds.size.y,bounds.size.z]},"tail":[tail.back().x,tail.back().y,tail.back().z],"body":[body.back().x,body.back().y,body.back().z]})
		if clip in ["Idle","Walk","Run","Fidget","Fidget2","Jump","Roll","Cast"]:
			check(tail.front().distance_to(tail.back())<.002 and body.front().distance_to(body.back())<.002,"Loop/action returns to the source anchor: "+clip)
		if clip in ["Walk","Run"]:
			var min_y:=INF;var max_y:=-INF;var min_x:=INF;var max_x:=-INF
			for point in tail:min_y=minf(min_y,point.y);max_y=maxf(max_y,point.y);min_x=minf(min_x,point.x);max_x=maxf(max_x,point.x)
			check(max_y-min_y>.15,"Cetacean flukes actually beat vertically: "+clip)
			check(max_x-min_x<(max_y-min_y)*.3,"Swimming uses vertical tail beats rather than a fishlike side stroke")
		if clip in ["Jump","Roll"]:
			check(body[4].y-body.front().y>1.,"Breach physically clears the water by a metre: "+clip)
		if clip=="Idle":check(head.front().z>body.front().z+.1,"The bottlenose faces the project's +Z heading")
	model.free()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../outputs/creatures/dolphin-trial"))
	var result:={"checks":checks,"failures":failures,"asset_sha256":FileAccess.get_sha256(asset_path),"import_sha256":FileAccess.get_sha256(asset_path+".import"),"recipe_sha256":FileAccess.get_sha256("res://../scripts/blender-prepare-dolphin.py"),"test_sha256":FileAccess.get_sha256("res://Presentation/DolphinMotionTests.gd"),"samples":rows,"scope":"Independent exported skin and measured motion only; not native, material, water-support or corpse acceptance."}
	var output:="public-motion.json" if asset_path.begins_with("res://Art/") else "motion.json"
	var file:=FileAccess.open("res://../outputs/creatures/dolphin-trial/"+output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "));file.close()
	print("DOLPHIN MOTION: ",checks," checks / ",failures," failures");quit(1 if failures else 0)
