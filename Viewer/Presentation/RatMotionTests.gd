extends SceneTree
## Independent rat donor review: actual exported skins, paths and comparison.
const Geometry=preload("res://Presentation/SkinGeometry.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;if failures<16:push_error(label)
func run() -> void:
	var folder:="res://local-art/rat"
	var prep: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+"/preparation.json"))
	var output:="res://../outputs/creatures/rat-trial";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var viewport:=SubViewport.new();viewport.size=Vector2i(1000,700);viewport.own_world_3d=true;viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	preload("res://Presentation/ItemStudio.gd").studio_lights(viewport)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=.8;viewport.add_child(camera);camera.position=Vector3(.85,.5,.9);camera.look_at(Vector3(0.,.07,0.))
	var samples: Array=[];var assets: Dictionary={};var envelope:=AABB();var initial_envelope:=true
	for treatment: String in ["source","modern"]:
		var path:=folder+"/rat-"+treatment+".glb";assets[treatment]={"sha256":FileAccess.get_sha256(path),"import_sha256":FileAccess.get_sha256(path+".import")}
		check(assets[treatment].sha256==prep.treatments[treatment].asset_sha256,"Exact pinned recipe output: "+treatment)
		var model: Node3D=load(path).instantiate();viewport.add_child(model)
		var rig: Skeleton3D=model.find_children("*","Skeleton3D",true,false)[0]
		var player: AnimationPlayer=model.find_children("*","AnimationPlayer",true,false)[0]
		var mesh: MeshInstance3D=model.find_children("*","MeshInstance3D",true,false)[0]
		check(rig.get_bone_count()==21,"All21 author rig bones remain")
		var arrays:=mesh.mesh.surface_get_arrays(0);var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS];var count: int=arrays[Mesh.ARRAY_VERTEX].size();var stride:=weights.size()/count
		check(arrays[Mesh.ARRAY_INDEX].size()/3==int(prep.treatments[treatment].triangles),"Measured refined/source topology")
		var valid:=stride==4
		for i in count:
			var total:=0.
			for j in stride:var weight:=weights[i*stride+j];total+=weight;valid=valid and is_finite(weight) and weight>=0.
			valid=valid and absf(total-1.)<.0001
		check(valid,"Every actual exported vertex has finite normalized skin weights")
		var head:=rig.find_bone("head");var paw:=rig.find_bone("base.001_L.001")
		check(head>=0 and paw>=0 and rig.find_bone("tail")>=0,"Real named head, foreleg and tail controls")
		var idle_head:=Vector3.ZERO;var eat_head:=Vector3.ZERO;var clip_paths: Dictionary={}
		var clips: Dictionary=prep.treatments[treatment].clips
		for clip: String in clips:
			check(player.has_animation(clip),"Declared category exists: "+clip)
			if not player.has_animation(clip):continue
			var animation:=player.get_animation(clip);animation.loop_mode=Animation.LOOP_NONE
			check(absf(animation.length-float(clips[clip].duration))<.018,"Category duration preserved to one60Hzframe: "+clip)
			player.play(clip,0.);player.pause();var first: Array[Transform3D]=[];var last: Array[Transform3D]=[];var path_points: Array=[]
			for i in 13:
				var phase:=float(i)/12.;player.seek(animation.length*phase,true);for frame in 2:await process_frame
				var bounds:=Geometry.deformed_bounds(mesh,rig);var finite:=bounds.position.is_finite() and bounds.size.is_finite()
				check(finite and bounds.size.length()>.2 and bounds.size.length()<.9,"Rat actual complete skin stays bounded")
				if treatment=="modern":check(bounds.position.y>-.006,"Refined actual skin floor clearance")
				var bones_finite:=true
				for bone in rig.get_bone_count():
					var pose:=rig.get_bone_global_pose(bone);bones_finite=bones_finite and pose.origin.is_finite() and pose.basis.is_finite() and pose.basis.determinant()>.9
					if i==0:first.append(pose)
					if i==12:last.append(pose)
				check(bones_finite,"Every retained bone is finite and uncollapsed")
				var head_point:=rig.to_global(rig.get_bone_global_pose(head).origin);path_points.append([head_point.x,head_point.y,head_point.z])
				if clip=="Idle" and i==0:idle_head=head_point
				if clip=="Eat" and i==6:eat_head=head_point
				if treatment=="modern":envelope=bounds if initial_envelope else envelope.merge(bounds);initial_envelope=false
				samples.append({"treatment":treatment,"clip":clip,"phase":phase,"bounds":{"position":[bounds.position.x,bounds.position.y,bounds.position.z],"size":[bounds.size.x,bounds.size.y,bounds.size.z]}})
				if i==6 and clip in ["Idle","Walk","Run","Attack","Eat","Death"]:
					await RenderingServer.frame_post_draw;var image:=viewport.get_texture().get_image();var changed:=0
					for y in range(0,image.get_height(),5):
						for x in range(0,image.get_width(),5):
							if image.get_pixel(x,y).a>.1:changed+=1
					check(changed>80,"ActualGPU renders the rat's skin")
					image.save_png(ProjectSettings.globalize_path(output+"/"+treatment+"-"+clip+".png"))
			clip_paths[clip]=path_points
			if bool(clips[clip].loop):
				var maximum:=0.
				for bone in first.size():maximum=maxf(maximum,rig.to_global(first[bone].origin).distance_to(rig.to_global(last[bone].origin)))
				check(maximum<(.0005 if treatment=="modern" else .012),"Measured source / corrected refined loop endpoint: "+clip)
		check(eat_head.y<idle_head.y-.012,"Authored feeding visibly lowers the real skull")
		check(clip_paths.Attack!=clip_paths.Attack2,"Alternate bite has a distinct head trajectory")
		model.queue_free();await process_frame
	var report:={"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"assets":assets,"samples":samples,
		"recipe_sha256":FileAccess.get_sha256("res://../scripts/blender-prepare-rat.py"),"test_sha256":FileAccess.get_sha256("res://Presentation/RatMotionTests.gd"),"preparation_sha256":FileAccess.get_sha256(folder+"/preparation.json"),
		"envelope":{"position":[envelope.position.x,envelope.position.y,envelope.position.z],"size":[envelope.size.x,envelope.size.y,envelope.size.z]},
		"scope":"Independent source donor and refinement review only. Native identity, hue, terrain, material and corpse acceptance remain required."}
	FileAccess.open(output+"/motion.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("RAT MOTION: ",checks," / ",failures," failures; ",samples.size()," actual skin samples")
	quit(0 if failures==0 else 1)
