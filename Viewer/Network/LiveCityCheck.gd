extends SceneTree
# Local validation uses the development account, never the remembered account.
var scene: Node3D
var failure := ""
var ack := -1
var visited := 0
var walking_active:=false
var walking_samples: Array[float]=[]
var previous_us:=0
func _process(_delta: float) -> bool:
 var now:=Time.get_ticks_usec()
 if walking_active and previous_us>0:walking_samples.append((now-previous_us)/1000.0)
 previous_us=now
 return false
func _initialize() -> void: call_deferred("run")
func until(test: Callable, seconds: float = 15.0) -> bool:
 var start := Time.get_ticks_msec()
 while not test.call():
  if not failure.is_empty() or Time.get_ticks_msec()-start > seconds*1000: return false
  await process_frame
 return true
func fail(message: String) -> void:
 push_error(message+" "+failure)
 if scene: scene.game.close()
 quit(1)
func route(start: Dictionary) -> Array:
 var origin := Vector3i(start.x,start.y,start.z)
 var queue: Array = [origin]
 var parent := {origin:origin}
 var directions := {}
 var cursor := 0
 while cursor < queue.size() and cursor < 12000:
  var at: Vector3i = queue[cursor]
  cursor += 1
  if at.x < 1600 and at.y < 1568:
   var path: Array = []
   while at != origin:
    path.push_front(directions[at])
    at = parent[at]
   return path
  for direction in [0,6,2,4,7,1,5,3]:
   var next: Dictionary = scene.movement_surface.predict({"x":at.x,"y":at.y,"z":at.z},direction)
   if next.is_empty(): continue
   var cell := Vector3i(next.x,next.y,next.z)
   var occupied := false
   for entity in scene.game.entities.values():
    if int(entity.get("serial",0)) != int(scene.game.player.serial) and int(entity.x)==cell.x and int(entity.y)==cell.y and absi(int(entity.z)-cell.z)<16: occupied=true
   if occupied: continue
   if parent.has(cell) or absi(cell.x-origin.x)>55 or absi(cell.y-origin.y)>55: continue
   parent[cell] = at
   directions[cell] = direction
   queue.append(cell)
 return []
func open_route_door(cell: Vector2i) -> bool:
 for serial in scene.game.world_items:
  var item: Dictionary = scene.game.world_items[serial]
  var rule: Dictionary = scene.world_items.definition(item)
  if rule.family != "door" or rule.get("is_open",false): continue
  if Vector2i(item.x,item.y) != cell: continue
  await create_timer(1.2).timeout
  scene.game.use_item(serial)
  return await until(func(): return scene.world_items.definition(scene.game.world_items.get(serial,item)).get("is_open",false))
 return false
func run() -> void:
 scene = load("res://Main.tscn").instantiate()
 root.add_child(scene)
 scene.accept_player_input = false
 if not await until(func(): return scene.world_ready,180): fail("City startup timeout"); return
 var stream: Node3D = scene.city_stream
 if stream == null or scene.game.preview_bounds.size != Vector2i(704,512): fail("City mode/bounds missing"); return
 if stream.loaded.size()!=9 or stream.destination_ready(Vector2i(1080,1400)): fail("Initial district readiness wrong"); return
 for district in stream.loaded.values():
  if district.position != Vector3.ZERO or district.get_meta("collision_triangles",0)<=0: fail("Missing local-frame collision"); return
 await physics_frame
 await physics_frame
 var ray := PhysicsRayQueryParameters3D.create(scene.point(1645,1575,200),scene.point(1645,1575,-100),1)
 if scene.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): fail("Physical floor absent beyond original crop"); return
 var before: Dictionary = stream.loaded.duplicate()
 stream.requested = Vector2i(1665,1591)
 await stream.refresh()
 var retained := 0
 for at in before:
  if stream.loaded.has(at) and is_instance_valid(before[at]) and before[at] == stream.loaded[at]: retained += 1
 if retained != 6 or stream.destination_ready(Vector2i(1537,1537)): fail("Collision eviction/retention failed"); return
 stream.requested = Vector2i(1602,1591)
 await stream.refresh()
 print("LIVE CITY COLLISION PASS: nine physical districts, six retained, outgoing district blocked, source-relative coordinates")
 var audit_path := "res://../Server/runtime/Data/UltimaClonePreview/audit.local.json"
 if not FileAccess.file_exists(audit_path): fail("Run Populate-Britain.cmd before testing native interactions"); return
 var audit: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(audit_path))
 var door_serial := 0
 var lamp_serial := 0
 # The audit now spans the whole city; keep the reference fixtures in the
 # original tavern crop so the route below means the same thing.
 var crop := Rect2i(1576,1568,64,64)
 for item in audit.items:
  if not crop.has_point(Vector2i(int(item.x),int(item.y))): continue
  if item.family=="door" and int(item.z)==0 and door_serial==0: door_serial=int(item.serial)
  if item.family=="lamp" and int(item.z)==0: lamp_serial=int(item.serial)
 if door_serial==0 or lamp_serial==0: fail("Native door/outdoor lamp fixture missing"); return
 scene.game.message_received.connect(func(message: String):
  if message.begins_with("UCVISIT1|"): visited=int(message.split("|")[1]))
 scene.game.failed.connect(func(reason: String): failure = reason)
 scene.game.movement_result.connect(func(accepted: bool,_at: Dictionary): ack = 1 if accepted else 0)
 scene.game.characters_received.connect(func(characters: Array,_cities: Array):
  for character in characters:
   if not character.name.is_empty():
    scene.game.select_character(character.slot,character.name)
    return)
 scene.game.connect_account(OS.get_environment("UO_DEV_USER"),OS.get_environment("UO_DEV_PASSWORD"))
 if not await until(func(): return scene.game.phase == "world"): fail("Native world entry failed"); return
 # Approach the reference tavern using the existing loopback-only server tool.
 scene.game.send_command("[PreviewVisit %d" % door_serial)
 if not await until(func(): return visited==door_serial and scene.game.player.z==0): fail("Ground-level native visit failed"); return
 await create_timer(1.2).timeout
 var door: Dictionary = scene.game.world_items.get(door_serial,{})
 if door.is_empty(): fail("Native door packet missing"); return
 if not scene.world_items.definition(door).get("is_open",false):
  scene.game.use_item(door_serial)
  if not await until(func(): return scene.world_items.definition(scene.game.world_items.get(door_serial,door)).get("is_open",false)): fail("Door opening failed"); return
 # Start the traversal outside the tavern: wandering native vendors can stand
 # in its doorway. They are genuine blockers, not a rendering failure.
 scene.game.send_command("[PreviewVisit %d" % lamp_serial)
 if not await until(func(): return visited==lamp_serial and scene.game.player.z==0): fail("Outdoor native visit failed"); return
 var path := route(scene.game.player)
 if path.is_empty(): fail("No conservative native route beyond old crop"); return
 walking_active=true
 for direction in path:
  var at: Dictionary = scene.game.player.duplicate()
  # The native protocol acknowledges turning separately from stepping.
  while scene.game.player.x==at.x and scene.game.player.y==at.y:
   var target: Vector2i = Vector2i(at.x,at.y)+preload("res://Presentation/MovementSurface.gd").OFFSETS[direction]
   await open_route_door(target)
   ack = -1
   if not await until(func(): return scene.game.walk(direction,true)): fail("Movement request timeout"); return
   if not await until(func(): return ack != -1): fail("Native acknowledgement timeout"); return
   if ack != 1:
    if await open_route_door(target):
     print("LIVE CITY: native closing door rejected movement; reopened via native use")
     continue
    fail("Server rejected city traversal at "+str(at)+" direction "+str(direction))
    return
 walking_active=false
 walking_samples.sort()
 if not walking_samples.is_empty():print("LIVE WALK FRAME TIMES: p95=",walking_samples[int(walking_samples.size()*0.95)]," ms / max=",walking_samples[-1]," ms / frames=",walking_samples.size())
 var endpoint: Dictionary = scene.game.player.duplicate()
 scene.game.request_position()
 if not await until(func(): return not scene.game.awaiting_position): fail("Native XYZ reconciliation timeout"); return
 if scene.game.player.x!=endpoint.x or scene.game.player.y!=endpoint.y or scene.game.player.z!=endpoint.z: fail("Native XYZ disagrees with prediction"); return
 if scene.game.player.x>=1600 or scene.game.player.y>=1568: fail("Did not cross old crop and district boundary"); return
 print("LIVE CITY WALK PASS: ",path.size()," accepted native run steps; crossed x=1600 district and y=1568 old crop; authoritative XYZ ",scene.game.player)
 if not await until(func(): return stream.settled(),90): fail("Background district completion timeout"); return
 if scene.minimap==null:fail("Native radar minimap missing");return
 await process_frame
 if not scene.minimap.visible or scene.minimap.location!=Vector2(endpoint.x+0.5,endpoint.y+0.5):fail("Radar position disagrees with native character");return
 var camera_distance: float=scene.distance
 var wheel:=InputEventMouseButton.new()
 wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN;wheel.pressed=true
 wheel.position=scene.minimap.get_global_rect().get_center()
 root.push_input(wheel)
 for frame in 3:await process_frame
 if scene.minimap.pixels_per_cell!=0.5 or scene.distance!=camera_distance or scene.minimap.textures.is_empty() or scene.minimap.textures.size()>36 or not scene.minimap.footer.text.contains(str(endpoint.x)):fail("Radar zoom/cache limit wrong");return
 print("LIVE MINIMAP PASS: native XYZ position, north-up marker, zoom and bounded original radar textures")
 if DisplayServer.get_name() != "headless":
  await create_timer(2.0).timeout
  await RenderingServer.frame_post_draw
  var output := ProjectSettings.globalize_path("res://../outputs/validation/live-britain.png")
  var saved := root.get_texture().get_image().save_png(output)
  print("LIVE CITY SCREENSHOT: ",saved," / ",output," / FPS ",Engine.get_frames_per_second()," / draws ",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
  root.get_texture().get_image().save_png(output.replace(".png","-"+RenderingServer.get_current_rendering_method()+".png"))
  if saved != OK: fail("Screenshot write failed"); return
 scene.game.return_to_britain()
 if not await until(func(): return scene.game.player.x==1602 and scene.game.player.y==1591 and scene.game.player.z==20): fail("Native home recovery failed"); return
 if not await until(func(): return stream.settled(),90): fail("Background district completion timeout"); return
 scene.game.close()
 scene.free()
 for frame in 3: await process_frame
 print("LIVE CITY PASS: native entry, door use, extended movement, server reconciliation and F6 recovery")
 quit()
