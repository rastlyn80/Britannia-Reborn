extends SceneTree
# Local streaming-stall profile along a fixed continuous run route. Movement
# waits for destination districts like native movement does; this is renderer
# and resource evidence, not a multiplayer traversal claim.
const ROUTE:=[Vector2i(1602,1591),Vector2i(1780,1591),Vector2i(1780,1700),Vector2i(1480,1700),Vector2i(1480,1480),Vector2i(1602,1480),Vector2i(1602,1591)]
const TILES_PER_SECOND:=8.0
var scene: Node3D
var frames: Array=[]
var sampling:=false
var previous_us:=0
var peak:=0
var deadline:=0
func _initialize() -> void:call_deferred("run")
func _process(_delta: float) -> bool:
 var now:=Time.get_ticks_usec()
 if sampling and previous_us>0:
  var viewport:=root.get_viewport_rid()
  frames.append({"frame":Engine.get_process_frames(),"ms":(now-previous_us)/1000.0,"render_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(viewport),"gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(viewport),"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0})
 previous_us=now
 peak=maxi(peak,int(Performance.get_monitor(Performance.MEMORY_STATIC)))
 if deadline>0 and Time.get_ticks_msec()>deadline:push_error("Streaming profile timeout");quit(1)
 return false
func percentile(values: Array, fraction: float) -> float:
 return float(values[mini(values.size()-1,int(values.size()*fraction))])
func run() -> void:
 var label:="profile"
 var laps:=1
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--label="):label=arg.substr(8)
  if arg.begins_with("--laps="):laps=int(arg.substr(7))
 deadline=Time.get_ticks_msec()+600000
 var start:=Time.get_ticks_msec()
 scene=load("res://Main.tscn").instantiate();root.add_child(scene)
 scene.accept_player_input=false
 while not scene.world_ready:await process_frame
 var startup:=Time.get_ticks_msec()-start
 var stream: Node3D=scene.city_stream
 while not stream.settled():await process_frame
 RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
 stream.phases.clear();stream.slow_phases.clear();stream.events.clear()
 var started_memory:=int(Performance.get_monitor(Performance.MEMORY_STATIC))
 sampling=true
 var position:=Vector2(ROUTE[0])
 var blocked_ms:=0.0
 var walk_start:=Time.get_ticks_msec()
 var lap_frames: Array=[]
 for lap_index in laps*(ROUTE.size()-1):
  var i:=1+lap_index%(ROUTE.size()-1)
  if i==1:lap_frames.append(frames.size())
  var target:=Vector2(ROUTE[i])
  while position.distance_to(target)>0.01:
   # Fixed per-frame advance keeps the visited sequence identical between runs.
   var step:=TILES_PER_SECOND/60.0
   var next:=position.move_toward(target,step)
   var cell:=Vector2i(floori(next.x),floori(next.y))
   stream.follow(cell)
   if stream.destination_ready(cell):position=next
   else:blocked_ms+=frames[-1].ms if not frames.is_empty() else 0.0
   scene.pivot.position=scene.entity_point(position.x,position.y,20)+Vector3.UP
   scene.distance=7;scene.pitch=-0.3
   if not stream.failed.is_empty():push_error(stream.failed);quit(1);return
   await process_frame
 sampling=false
 var walk_ms:=Time.get_ticks_msec()-walk_start
 var times: Array=frames.map(func(f): return f.ms);times.sort()
 var gpu: Array=frames.map(func(f): return f.gpu_ms);gpu.sort()
 var worst: Array=frames.duplicate();worst.sort_custom(func(a,b): return a.ms>b.ms)
 worst=worst.slice(0,12)
 for f in worst:
  f.phases=stream.slow_phases.filter(func(p): return absi(int(p.frame)-int(f.frame))<=1)
  f.events=stream.events.filter(func(e): return int(e.frame)>=int(f.frame)-3 and int(e.frame)<=int(f.frame)+1).map(func(e): return str(int(e.frame)-int(f.frame))+":"+str(e.event))
 var lap_max: Array=[]
 lap_frames.append(frames.size())
 for lap_index in lap_frames.size()-1:
  var slice: Array=frames.slice(lap_frames[lap_index],lap_frames[lap_index+1]).map(func(f): return f.ms)
  slice.sort()
  lap_max.append({"max_ms":slice[-1],"p99_ms":percentile(slice,.99),"over_33ms":slice.filter(func(t): return t>33.4).size(),"over_100ms":slice.filter(func(t): return t>100).size()})
 var report:={"label":label,"laps":lap_max,"renderer":RenderingServer.get_current_rendering_method(),"route":ROUTE.map(func(v): return [v.x,v.y]),"tiles_per_second":TILES_PER_SECOND,"startup_ms":startup,"walk_ms":walk_ms,"blocked_ms":blocked_ms,"frames":times.size(),"p50_ms":percentile(times,.5),"p95_ms":percentile(times,.95),"p99_ms":percentile(times,.99),"max_ms":times[-1],"frames_over_33ms":times.filter(func(t): return t>33.4).size(),"frames_over_100ms":times.filter(func(t): return t>100).size(),"gpu_p99_ms":percentile(gpu,.99),"gpu_max_ms":gpu[-1],"start_godot_bytes":started_memory,"end_godot_bytes":int(Performance.get_monitor(Performance.MEMORY_STATIC)),"peak_godot_bytes":peak,"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"installs":stream.installs,"phases":stream.phases,"worst_frames":worst}
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../outputs/validation"))
 var file:=FileAccess.open("res://../outputs/validation/streaming-walk-%s-%s.local.json" % [label,report.renderer],FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"\t"));file.close()
 print("STREAMING PROFILE: ",label," / ",report.renderer," / p50 ",report.p50_ms," p95 ",report.p95_ms," p99 ",report.p99_ms," max ",report.max_ms," / >33ms ",report.frames_over_33ms," >100ms ",report.frames_over_100ms," / blocked ",blocked_ms," ms / startup ",startup," ms")
 scene.free()
 await process_frame
 quit()
