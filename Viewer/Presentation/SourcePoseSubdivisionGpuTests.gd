extends SceneTree
## Real GPU comparison against the original animated source surface.
const Refine=preload("res://Presentation/SourcePoseSubdivision.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
var viewport: SubViewport
func _initialize() -> void:
	create_timer(300.).timeout.connect(func():push_error("Source subdivision GPU deadline");quit(1));call_deferred("run")
func capture() -> Image:
	for frame in 3:await process_frame
	await RenderingServer.frame_post_draw;return viewport.get_texture().get_image()
func run() -> void:
	viewport=SubViewport.new();viewport.size=Vector2i(512,512);viewport.own_world_3d=true;viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var path:="res://local-art/creatures/slimes_slime-original.gltf";var model: Node3D=load(path).instantiate();viewport.add_child(model);var rig: Skeleton3D=model.find_children("*","Skeleton3D",true,false)[0];var player: AnimationPlayer=model.find_children("*","AnimationPlayer",true,false)[0];player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL;var instance: MeshInstance3D=model.find_children("*","MeshInstance3D",true,false)[0];var original_mesh:=instance.mesh;var original_skin:=instance.skin;var material:=original_mesh.surface_get_material(0).duplicate() as StandardMaterial3D;material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR;material.alpha_scissor_threshold=.12;instance.material_override=material
	var detail:=Refine.apply(instance,rig,2,0.);var refined_mesh:=instance.mesh;var refined_skin:=instance.skin;var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;viewport.add_child(camera);var checks:=0;var failures:=0;var samples: Array=[]
	for clip in ["Idle","Walk","Run","Attack","Hit","Death","Fidget"]:
		player.get_animation(clip).loop_mode=Animation.LOOP_NONE;player.play(clip,0.)
		for phase in [0.,.1173,.2371,.3871,.5831,.8371,1.]:
			player.seek(player.current_animation_length*phase,true);player.advance(0.);player.pause();rig.force_update_all_bone_transforms();instance.mesh=original_mesh;instance.skin=original_skin;var bounds:=Geometry.deformed_bounds(instance,rig);camera.size=bounds.size.length()*1.05;camera.position=bounds.get_center()+Vector3(1.8,1.1,3.)*bounds.size.length();camera.look_at(bounds.get_center());var source:=await capture();instance.mesh=refined_mesh;instance.skin=refined_skin;var refined:=await capture();var occupied:=0;var changed:=0
			for y in source.get_height():
				for x in source.get_width():
					var a:=source.get_pixel(x,y);var b:=refined.get_pixel(x,y)
					if maxf(a.r,maxf(a.g,a.b))>.04:occupied+=1
					if Vector3(a.r-b.r,a.g-b.g,a.b-b.b).length()>.04:changed+=1
			var fraction:=float(changed)/maxi(1,occupied);checks+=2
			if occupied<100 or fraction>.02:failures+=1;if failures<12:push_error("GPU source subdivision mismatch %s phase%s: %s/%s pixels"%[clip,phase,changed,occupied])
			samples.append({"clip":clip,"phase":phase,"original_pixels":occupied,"changed_pixels":changed,"changed_fraction":fraction})
	var report:={"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"source_bones":rig.get_bone_count(),"refinement":detail,"samples":samples,"asset_sha256":FileAccess.get_sha256(path),"import_sha256":FileAccess.get_sha256(path+".import"),"recipe_sha256":FileAccess.get_sha256("res://Presentation/SourcePoseSubdivision.gd"),"test_sha256":FileAccess.get_sha256("res://Presentation/SourcePoseSubdivisionGpuTests.gd"),"scope":"Actual source Slime GPU surface/UV/alpha under49original poses versus exact zero-offset736triangle/eight-weight conditional-bind subdivision. Same material/camera/rig and original source scale. Authored1.5mm shaping/modern shader/terrain/native ownership require separate actual-avatar proofs."};FileAccess.open("res://../outputs/creatures/amorphous/subdivision-gpu.json",FileAccess.WRITE).store_string(JSON.stringify(report));print("SOURCE SUBDIVISION GPU: ",checks," / ",failures," failures / ",samples.size()," actual source/refined pose pairs / binds ",detail.binds);model.free();quit(1 if failures else 0)
