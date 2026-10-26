extends SceneTree
# Local renderer/resource stress test, not a multiplayer traversal claim.
var scene: Node3D
var samples: Array[float]=[]
var sampling:=false
var previous_us:=0
var peak:=0
var deadline:=0
func _initialize() -> void:call_deferred("run")
func fail(message: String) -> void:
 push_error(message)
 quit(1)
func _process(_delta: float) -> bool:
 var now:=Time.get_ticks_usec()
 if sampling and previous_us>0:samples.append((now-previous_us)/1000.0)
 previous_us=now
 peak=maxi(peak,int(Performance.get_monitor(Performance.MEMORY_STATIC)))
 if deadline>0 and Time.get_ticks_msec()>deadline:fail("Streaming stress timeout")
 return false
func run() -> void:
 deadline=Time.get_ticks_msec()+240000
 var start:=Time.get_ticks_msec()
 scene=load("res://Main.tscn").instantiate();root.add_child(scene)
 scene.accept_player_input=false
 while not scene.world_ready:await process_frame
 var startup:=Time.get_ticks_msec()-start
 var stream: Node3D=scene.city_stream
 var route:=[Vector2i(1602,1591),Vector2i(1665,1591),Vector2i(1729,1591),Vector2i(1665,1591),Vector2i(1602,1591),Vector2i(1535,1591),Vector2i(1602,1591)]
 var retained: Array[int]=[]
 sampling=true
 for lap in 2:
  for at in route:
   scene.pivot.position=scene.entity_point(at.x,at.y,20)+Vector3.UP
   scene.distance=7;scene.pitch=-0.3
   stream.requested=at
   await stream.refresh()
   while not stream.settled():
    if not stream.failed.is_empty():fail(stream.failed);return
    await process_frame
   if stream.loaded.size()>9 or stream.sources.size()>9 or stream.pending.size()>2 or stream.far_nodes.size()>25 or stream.macro_nodes.size()>25 or stream.surface.terrain.size()>36864:
    fail("Runtime district/source/job retention exceeded fixed limits");return
   await create_timer(0.3).timeout
  retained.append(int(Performance.get_monitor(Performance.MEMORY_STATIC)))
 sampling=false;samples.sort()
 if retained[1]>retained[0]+32*1024*1024:fail("Repeated identical journey retained more than 32 MiB of additional engine memory");return
 var report:={"renderer":RenderingServer.get_current_rendering_method(),"startup_ms":startup,"peak_godot_bytes":peak,"lap_end_godot_bytes":retained,"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"frames":samples.size(),"p95_ms":samples[int(samples.size()*0.95)],"p99_ms":samples[int(samples.size()*0.99)],"max_ms":samples[-1],"max_activation_ms":stream.max_install_us/1000.0,"installs":stream.installs}
 var file:=FileAccess.open("res://../outputs/validation/streaming-"+report.renderer+".local.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(report));file.close()
 print("STREAMING STRESS PASS: 14 district destinations / bounded source, collision and scenery / memory plateau / ",JSON.stringify(report))
 scene.free()
 await process_frame
 quit()
