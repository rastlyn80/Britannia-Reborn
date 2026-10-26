extends SceneTree
# Offline diagnostic images with an explicitly local server-decoration snapshot.
# No login, account movement, gameplay action or server mutation occurs here.
var scene: Node3D
func _initialize() -> void:call_deferred("run")
func run() -> void:
 root.size=Vector2i(1280,800)
 var label:="after"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--label="):label=arg.substr(8)
 var folder:=OS.get_environment("UO_ART_OUTPUT")
 if folder.is_empty():folder=ProjectSettings.globalize_path("res://../outputs/art-review")
 folder=folder.path_join(label)
 DirAccess.make_dir_recursive_absolute(folder)
 scene=load("res://Main.tscn").instantiate();root.add_child(scene)
 var deadline:=Time.get_ticks_msec()+300000
 while not scene.world_ready:
  if Time.get_ticks_msec()>deadline:push_error("Art block startup timeout");quit(1);return
  await process_frame
 if scene.city_stream:
  while not scene.city_stream.settled():
   if Time.get_ticks_msec()>deadline:push_error("Art block streaming timeout");quit(1);return
   await process_frame
 scene.set_process(false)
 for child in scene.get_children():
  if child is CanvasLayer:child.hide()
 var snapshot_path:=OS.get_environment("UO_ART_SNAPSHOT")
 if snapshot_path.is_empty():snapshot_path="res://../Server/runtime/Data/UltimaClonePreview/audit.local.json"
 if FileAccess.file_exists(snapshot_path):
  var snapshot: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(snapshot_path))
  scene.world_items.definitions.merge(snapshot.definitions,false)
  for item in snapshot.items:
   scene.game.world_items[int(item.serial)]=item
  for item in snapshot.items:scene.world_items.upsert(int(item.serial),item)
 scene.camera.reparent(scene)
 var views:=[
  ["street",Vector3(1636,1.7,1592),Vector3(1626,2.8,1587)],
  ["tavern",Vector3(1619,1.65,1582),Vector3(1619,1.2,1588)],
  ["games",Vector3(1629,1.65,1590),Vector3(1622,1.0,1587)],
  ["basement",Vector3(1621,-2.35,1589),Vector3(1614,-3.0,1583)],
  ["bedroom",Vector3(1624,-2.35,1586),Vector3(1628,-3.4,1583)],
  ["inn-street",Vector3(1584,5.8,1604),Vector3(1584,7.1,1590)],
  ["inn-room",Vector3(1583,5.65,1588),Vector3(1578,4.8,1585)],
  ["landscape",Vector3(1590,9,1618),Vector3(1599,2.8,1608)],
  ["riverbank",Vector3(1560,20,1534),Vector3(1551,0,1520)],
  ["bridge",Vector3(1385,18,1736),Vector3(1394,2,1749)],
  ["bridge-pier",Vector3(1394,1.2,1737),Vector3(1390,1.5,1743)],
  ["bridge-east",Vector3(1556,3.5,1527),Vector3(1546,1.5,1520)]
 ]
 # Targeted inspection: --view=name:x,y,z:tx,ty,tz (native X, metres, native Y)
 # replaces the fixed set and streams districts around each target.
 var custom:=[]
 for arg in OS.get_cmdline_user_args():
  if not arg.begins_with("--view="):continue
  var parts:=arg.substr(7).split(":")
  var eye:=parts[1].split_floats(",");var target:=parts[2].split_floats(",")
  custom.append([parts[0],Vector3(eye[0],eye[1],eye[2]),Vector3(target[0],target[1],target[2])])
 if not custom.is_empty():views=custom
 var captured:=0
 for view in views:
  if "--extra-only" in OS.get_cmdline_user_args() and view[0] not in ["riverbank","bridge","bridge-pier","bridge-east"]:continue
  if scene.city_stream and (not custom.is_empty() or view[0] in ["riverbank","bridge","bridge-pier","bridge-east"]):
   var focus:=Vector2i(int(view[2].x),int(view[2].z))
   scene.city_stream.requested=focus
   await scene.city_stream.refresh()
   while not scene.city_stream.settled():
    if not scene.city_stream.failed.is_empty():push_error(scene.city_stream.failed);quit(1);return
    if Time.get_ticks_msec()>deadline:push_error("Art inspection district timeout");quit(1);return
    await process_frame
  scene.camera.position=Vector3(view[1].x-scene.world.originX,view[1].y,view[1].z-scene.world.originY)
  scene.camera.look_at(Vector3(view[2].x-scene.world.originX,view[2].y,view[2].z-scene.world.originY))
  for i in 8:await process_frame
  await RenderingServer.frame_post_draw
  assert(root.get_texture().get_image().save_png(folder.path_join(view[0]+".png"))==OK)
  captured+=1
  print("ART VIEW: ",view[0])
 print("ART BLOCK CAPTURE PASS: ",captured," offline diagnostic views / ",label)
 scene.free();await process_frame;quit()
