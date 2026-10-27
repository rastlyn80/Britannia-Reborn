extends Node3D
# Runtime contains only bounded, prepared resources. Global topology belongs to
# BakeStreaming; no source reconstruction or collision generation runs here.
const MAX_PENDING := 2
const FRAME_BUDGET_US := 2000
const Compact := preload("res://Presentation/CompactDistrict.gd")
var loaded: Dictionary = {}
var far_nodes: Dictionary = {}
var macro_nodes: Dictionary = {}
var sources: Dictionary = {}
var requested := Vector2i(1602,1591)
var busy := false
var scene: Node3D
var bounds := Rect2i()
var world: Dictionary
var reconstruction := preload("res://Presentation/Reconstruction.gd").new()
var surface := preload("res://Presentation/MovementSurface.gd").new()
var shell := preload("res://Presentation/InteriorShell.gd").new()
var horizon: Node3D
var folder := ""
var known: Dictionary = {}
var macro_known: Dictionary = {}
var wanted: Dictionary = {}
var near_wanted: Dictionary = {}
var pending: Dictionary = {}
var center := Vector2i(-100000,-100000)
var failed := ""
var max_install_us := 0
var installs := 0
var stale_jobs := 0
var source_dirty := false
var retiring: Array[Node3D]=[]
var activating: Dictionary={}
# Main-thread phase timing for streaming-stall diagnosis: totals/maxima per
# phase and individual phases over 4 ms with their frame number.
var phases: Dictionary={}
var slow_phases: Array=[]
var fresh_nodes: Array[Node3D]=[]
var events: Array=[]

func note(event: String) -> void:
 if events.size()<4096:events.append({"frame":Engine.get_process_frames(),"event":event})

func measure(phase: String, started_us: int, detail: String="") -> void:
 var spent:=Time.get_ticks_usec()-started_us
 var entry: Dictionary=phases.get(phase,{"count":0,"total_us":0,"max_us":0})
 entry.count+=1;entry.total_us+=spent;entry.max_us=maxi(entry.max_us,spent)
 phases[phase]=entry
 if spent>=4000 and slow_phases.size()<512:slow_phases.append({"frame":Engine.get_process_frames(),"phase":phase,"ms":spent/1000.0,"detail":detail})

var fresh_origins: Array[Vector2i] = []
class DecodeJob extends RefCounted:
 var resource: Resource
 var result: Dictionary
 func run() -> void:
  if resource.land.is_empty():return
  result=resource.decode()
  var terrain_index: Dictionary={}
  var static_index: Dictionary={}
  for tile in result.terrain:terrain_index[Vector2i(tile.x,tile.y)]=tile
  for tile in result.statics:
   var cell:=Vector2i(tile.x,tile.y)
   if not static_index.has(cell):static_index[cell]=[]
   static_index[cell].append(tile)
  result.terrain_index=terrain_index
  result.static_index=static_index

static func owner(cell: Vector2i, size: int = 64) -> Vector2i:
 return Vector2i(floori(float(cell.x)/size)*size,floori(float(cell.y)/size)*size)

func prepare(owner_scene: Node3D) -> bool:
 scene=owner_scene
 var path:=preload("res://Presentation/GraphicsMode.gd").prepared(ProjectSettings.globalize_path("res://../outputs/britain")).path_join("index.json")
 # A modern cache that has not been prepared yet falls back to classic.
 if not FileAccess.file_exists(path):path=ProjectSettings.globalize_path("res://../outputs/britain/prepared/index.json")
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--stream-index="):path=arg.substr(15)
 if not FileAccess.file_exists(path):
  push_error("Prepare streaming data with scripts/prepare-streaming.ps1 first.")
  return false
 var index: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
 if not index is Dictionary or int(index.get("schema",0))!=1:return false
 folder=path.get_base_dir()
 bounds=Rect2i(index.originX,index.originY,index.width,index.height)
 for pair in index.chunks:known[Vector2i(int(pair[0]),int(pair[1]))]=true
 for pair in index.macros:macro_known[Vector2i(int(pair[0]),int(pair[1]))]=true
 world={"schema":1,"facet":"Trammel","originX":bounds.position.x,"originY":bounds.position.y,"width":bounds.size.x,"height":bounds.size.y,"elevationScale":0.2,"landData":index.landData,"staticData":index.staticData,"terrain":[],"statics":[],"provenance":"LOCAL TRAMMEL / prepared streaming / ModernUO authoritative"}
 preload("res://Presentation/SurfaceLibrary.gd").source_origin=Vector2(bounds.position)
 reconstruction.catalog=index.catalog
 reconstruction.index(world)
 surface.index(world)
 horizon=Node3D.new()
 horizon.name="StreamedHorizon"
 add_child(horizon)
 await refresh()
 return failed.is_empty()

func destination_ready(cell: Vector2i) -> bool:
 return bounds.has_point(cell) and loaded.has(owner(cell))

func path_for(kind: String, at: Vector2i) -> String:
 return folder.path_join("%s_%d_%d.res" % [kind,at.x,at.y])

func follow(cell: Vector2i) -> void:
 requested=cell
 if owner(cell)!=center: select_window()

func select_window() -> void:
 center=owner(requested)
 wanted.clear()
 near_wanted.clear()
 for dy in range(-2,3):
  for dx in range(-2,3):
   var at:=center+Vector2i(dx,dy)*64
   if not known.has(at):continue
   var kind:="near" if absi(dx)<=1 and absi(dy)<=1 else "far"
   if kind=="near":near_wanted[at]=true
   wanted[path_for(kind,at)]={"kind":kind,"at":at,"priority":dx*dx+dy*dy+(0 if kind=="near" else 100)}
 var macro_center:=owner(requested,256)
 for dy in range(-2,3):
  for dx in range(-2,3):
   var at:=macro_center+Vector2i(dx,dy)*256
   if macro_known.has(at):wanted[path_for("macro",at)]={"kind":"macro","at":at,"priority":200+dx*dx+dy*dy}
 # Outgoing nodes and source indices are actually released, never hidden caches.
 for at in loaded.keys():
  if not near_wanted.has(at):
   retire(loaded[at])
   loaded.erase(at)
   sources.erase(at)
   surface.remove_chunk(at)
   reconstruction.supports.remove_chunk(at)
   source_dirty=true
 for at in far_nodes.keys():
  if not wanted.has(path_for("far",at)) and (not near_wanted.has(at) or loaded.has(at)):
   retire(far_nodes[at]);far_nodes.erase(at)
 for at in macro_nodes.keys():
  if not wanted.has(path_for("macro",at)):retire(macro_nodes[at]);macro_nodes.erase(at)
 for path in pending:
  var record: Dictionary=pending[path]
  if not wanted.has(path) and record.has("node"):
   record.node.hide()
   activating.erase(record.at)
 update_horizon()
 busy=not near_complete()

func near_complete() -> bool:
 for at in near_wanted:
  if not loaded.has(at):return false
 return true

func settled() -> bool:
 if not retiring.is_empty():return false
 if not pending.is_empty():return false
 for record in wanted.values():
  if not resident(record):return false
 return true

func resident(record: Dictionary) -> bool:
 match record.kind:
  "near":return loaded.has(record.at)
  "far":return far_nodes.has(record.at)
  "macro":return macro_nodes.has(record.at)
 return false

func refresh() -> void:
 select_window()
 while not near_complete() and failed.is_empty():await get_tree().process_frame
 busy=false

func error(message: String) -> void:
 failed=message
 push_error(message)
 if scene and scene.world_ready:scene.game.message_received.emit(message)

func _process(_delta: float) -> void:
 if folder.is_empty() or not failed.is_empty():return
 var start:=Time.get_ticks_usec()
 while not retiring.is_empty():
  var old: Node3D=retiring[0]
  var free_start:=Time.get_ticks_usec()
  if old.get_child_count()>0:old.get_child(old.get_child_count()-1).free()
  else:retiring.pop_front();old.free()
  measure("retire-free",free_start)
  if Time.get_ticks_usec()-start>=FRAME_BUDGET_US:return
 # At most two resource/decode jobs exist. A result is retrieved only after
 # completion, so load_threaded_get never waits on disk in the render thread.
 for path in pending.keys():
  var record: Dictionary=pending[path]
  if record.has("task"):
   if not record.get("task_done",false):
    if not WorkerThreadPool.is_task_completed(record.task):continue
    WorkerThreadPool.wait_for_task_completion(record.task)
    record.task_done=true
    note("decoded "+str(record.kind))
   if not wanted.has(path):
    discard(record)
    pending.erase(path)
    stale_jobs+=1
    continue
   if not record.has("next_child"):
    record.next_child=0
    var root_start:=Time.get_ticks_usec()
    record.node=record.resource.root_scene.instantiate()
    if record.kind=="near":add_child(record.node)
    else:horizon.add_child(record.node)
    measure("root-"+str(record.kind),root_start)
   while record.next_child<record.resource.parts.size():
    var attach_start:=Time.get_ticks_usec()
    var part: Node=record.resource.parts[record.next_child].instantiate()
    measure("instantiate-"+str(record.kind),attach_start,part.get_class())
    if part is PhysicsBody3D:
     if not record.has("deferred"):record.deferred=[]
     for shape_node in part.find_children("*","CollisionShape3D",true,false):
      if shape_node.has_meta("deferred_faces"):record.deferred.append(shape_node)
    var tree_start:=Time.get_ticks_usec()
    record.node.add_child(part)
    measure("enter-tree-"+str(record.kind),tree_start)
    if record.kind=="near" and record.next_child==0:
     # Terrain is the first baked part. Switch its coarse ownership now, while
     # remaining meshes warm up progressively; native entry stays gated until
     # every collision/render part is installed.
     activating[record.at]=true
     if far_nodes.has(record.at):retire(far_nodes[record.at]);far_nodes.erase(record.at)
     update_horizon()
    max_install_us=maxi(max_install_us,Time.get_ticks_usec()-attach_start)
    record.next_child+=1
    if Time.get_ticks_usec()-start>=FRAME_BUDGET_US:break
   # Bounded collision slices; before world entry the initial window
   # materializes completely, as it previously did.
   var deferred: Array=record.get("deferred",[])
   while not deferred.is_empty():
    if scene and scene.world_ready and Time.get_ticks_usec()-start>=FRAME_BUDGET_US:break
    var shape_start:=Time.get_ticks_usec()
    var shape_node: CollisionShape3D=deferred.pop_back()
    if is_instance_valid(shape_node):Compact.materialize(shape_node)
    measure("collision-slice",shape_start)
   if record.next_child==record.resource.parts.size() and deferred.is_empty():
    install(record,record.node,record.job.result)
    pending.erase(path)
  else:
   var status:=ResourceLoader.load_threaded_get_status(path)
   if status==ResourceLoader.THREAD_LOAD_FAILED or status==ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
    pending.erase(path);error("Prepared district could not load: "+path);return
   if status!=ResourceLoader.THREAD_LOAD_LOADED:continue
   note("loaded "+str(record.kind))
   var get_start:=Time.get_ticks_usec()
   var resource: Resource=ResourceLoader.load_threaded_get(path)
   measure("threaded-get",get_start)
   if not wanted.has(path):pending.erase(path);stale_jobs+=1;continue
   var job:=DecodeJob.new();job.resource=resource
   record.resource=resource;record.job=job
   record.task=WorkerThreadPool.add_task(job.run)
  if Time.get_ticks_usec()-start>=FRAME_BUDGET_US:break
 if source_dirty:refresh_source_window()
 if not window_queue.is_empty() or not releasing.is_empty():
  var window_start:=Time.get_ticks_usec()
  advance_source_window()
  measure("source-window",window_start)
 busy=not near_complete()
 var queue: Array=wanted.values()
 queue.sort_custom(func(a:Dictionary,b:Dictionary):return a.priority<b.priority)
 for record in queue:
  if pending.size()>=MAX_PENDING:break
  var path:=path_for(record.kind,record.at)
  if pending.has(path) or resident(record):continue
  if ResourceLoader.load_threaded_request(path,"Resource")!=OK:error("Cannot request prepared resource: "+path);return
  note("request "+str(record.kind))
  pending[path]=record.duplicate()

func install(record: Dictionary, node: Node3D, decoded: Dictionary) -> void:
 var start:=Time.get_ticks_usec()
 node.show()
 if record.kind=="near":
  activating.erase(record.at)
  loaded[record.at]=node
  sources[record.at]=decoded
  surface.add_chunk(decoded)
  reconstruction.supports.add_chunk(record.at,decoded.terrain_index,decoded.static_index)
  fresh_origins.append(record.at)
  decoded.erase("terrain_index")
  decoded.erase("static_index")
  fresh_nodes.append(node)
  source_dirty=true
  if far_nodes.has(record.at):retire(far_nodes[record.at]);far_nodes.erase(record.at)
 else:
  if record.kind=="far":far_nodes[record.at]=node
  else:macro_nodes[record.at]=node
 update_horizon()
 max_install_us=maxi(max_install_us,Time.get_ticks_usec()-start)
 measure("install-"+str(record.kind),start)
 note("installed "+str(record.kind))
 installs+=1

# The merged source window (~50k shared records) is rebuilt one district per
# frame and swapped in when complete; replaced arrays are released in slices.
# Support and movement lookups are already per district and update at install.
var window_queue: Array=[]
var next_terrain: Array=[]
var next_statics: Array=[]
var releasing: Array=[]

func refresh_source_window() -> void:
 source_dirty=false
 window_queue=sources.keys()
 next_terrain=[]
 next_statics=[]
 # Startup consumers (fixtures, movement index) read the window immediately.
 if not (scene and scene.world_ready):
  while not window_queue.is_empty():advance_source_window()

func advance_source_window() -> void:
 if not window_queue.is_empty():
  var at: Vector2i=window_queue.pop_back()
  if sources.has(at):
   next_terrain.append_array(sources[at].terrain)
   next_statics.append_array(sources[at].statics)
  if not window_queue.is_empty():return
  releasing.append(world.terrain);releasing.append(world.statics)
  world.terrain=next_terrain
  world.statics=next_statics
  next_terrain=[];next_statics=[]
  if scene and scene.world_ready:
   scene.world_items.refresh_source_records(true)
   scene.world_items.rebuild_in_chunks(fresh_origins)
   fresh_origins.clear()
   for node in fresh_nodes:
    if is_instance_valid(node):scene.world_items.suppress_streamed_posts(node)
  fresh_nodes.clear()
 elif not releasing.is_empty():
  var old: Array=releasing.back()
  old.resize(maxi(0,old.size()-6000))
  if old.is_empty():releasing.pop_back()

func update_horizon() -> void:
 var rectangles:=PackedVector4Array()
 var covered: Dictionary=loaded.duplicate()
 covered.merge(activating,true)
 for at in covered:rectangles.append(Vector4(at.x,at.y,at.x+64,at.y+64))
 var count:=rectangles.size()
 while rectangles.size()<16:rectangles.append(Vector4(-100,-100,-100,-100))
 for root in macro_nodes.values():
  for mesh in root.get_children():
   if mesh is MeshInstance3D:
    mesh.material_override.set_shader_parameter("detail_rects",rectangles)
    mesh.material_override.set_shader_parameter("detail_count",count)

func discard(record: Dictionary) -> void:
 activating.erase(record.at)
 if record.has("node") and is_instance_valid(record.node):record.node.free()

func retire(node: Node3D) -> void:
 note("retire")
 node.hide()
 retiring.append(node)

func _exit_tree() -> void:
 for record in pending.values():
  if record.has("task"):
   if not record.get("task_done",false):WorkerThreadPool.wait_for_task_completion(record.task)
   discard(record)
