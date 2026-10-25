extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var scene = load("res://Main.tscn").instantiate()
 root.add_child(scene)
 await process_frame
 scene.set_process(false)
 scene.camera.reparent(scene)
 scene.camera.global_position=scene.entity_point(1630,1604,85)
 scene.camera.look_at(scene.entity_point(1617,1586,10))
 for i in 40: await process_frame
 var start := Time.get_ticks_msec()
 for i in 60: await process_frame
 var ms := (Time.get_ticks_msec()-start)/60.0
 print("DISTRICT RENDER: ",ms," ms/frame; drawcalls ",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
 scene.queue_free()
 for i in 5: await process_frame
 quit()
