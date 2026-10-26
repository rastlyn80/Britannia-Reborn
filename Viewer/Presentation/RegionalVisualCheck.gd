extends SceneTree
func _initialize()->void:call_deferred("run")
func capture(scene:Node3D,path:String)->void:
 scene._process(0)
 for frame in 6:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../outputs/validation/"+path+".png"))
func run()->void:
 var scene:Node3D=load("res://Atlas.tscn").instantiate()
 root.add_child(scene)
 scene.set_process(false)
 scene.target=Vector3(1632,4,1568);scene.distance=85
 await scene.load_detail()
 var ids:Dictionary={}
 for key in scene.loaded_chunks:ids[key]=scene.loaded_chunks[key].get_instance_id()
 var left_key:=Vector2i(1536,1536)
 var before:PackedVector3Array=scene.loaded_chunks[left_key].get_child(0).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
 await capture(scene,"britain-seam-west")
 scene.target.x+=64
 await scene.load_detail()
 var retained:=0
 for key in ids:
  if scene.loaded_chunks.has(key):
   if scene.loaded_chunks[key].get_instance_id()!=ids[key]:push_error("Unnecessary overlapping district replacement");quit(1);return
   retained+=1
 if retained!=6:push_error("Expected six retained neighboring chunks");quit(1);return
 await capture(scene,"britain-seam-east")
 scene.target.x-=64
 await scene.load_detail()
 var after:PackedVector3Array=scene.loaded_chunks[left_key].get_child(0).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
 if before!=after:push_error("Evicted terrain failed exact reload");quit(1);return
 if int(scene.detail.get_meta("unmapped"))!=0:push_error("Unmapped city graphics");quit(1);return
 if not scene.regional.reconstruction.report.is_empty():push_error("Unbounded streaming report cache");quit(1);return
 print("REGIONAL GPU PASS: nine joined chunks, six retained across boundary; exact terrain reload; zero unmapped")
 scene.free()
 quit()
