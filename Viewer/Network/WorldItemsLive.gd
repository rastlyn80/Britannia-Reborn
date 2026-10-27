extends SceneTree
var scene: Node3D
var session: Node
var error := ""
var visual := false
var opened := 0
var received_contents := -1
var sign_serial := 0
var sign_text := ""
var home := false
var repeat_created := -1
var book_pages := {}
var board_name := ""
var rolled := false
var native_gump := {}
func _initialize() -> void: call_deferred("run")
func until(condition: Callable,seconds: float = 8.0) -> bool:
 var start := Time.get_ticks_msec()
 while not condition.call():
  if not error.is_empty() or Time.get_ticks_msec()-start > seconds*1000: return false
  await process_frame
 return true
func fail(reason: String) -> void:
 push_error(reason+" "+error)
 if session: session.close()
 quit(1)
func visit(item: Dictionary) -> bool:
 session.send_command("[PreviewVisit %d" % int(item.serial))
 return await until(func(): return session.world_items.has(int(item.serial)) and maxi(absi(int(session.player.x)-int(item.x)),absi(int(session.player.y)-int(item.y))) <= 2 and absi(int(session.player.z)-int(item.z)) <= 16)
func interact(item: Dictionary) -> bool:
 if not visual: return session.use_item(int(item.serial))
 var serial := int(item.serial)
 if not scene.world_items.nodes.has(serial): return false
 var node: Node3D = scene.world_items.nodes[serial]
 var body: StaticBody3D = node.get_node_or_null("Hinge/PickBody") if item.family == "door" else node.get_node_or_null("PickBody")
 if not body: return false
 var target: Vector3 = body.get_node("PickShape").global_position
 scene.camera.reparent(scene)
 scene.camera.position = scene.entity_point(session.player.x,session.player.y,session.player.z)+Vector3.UP*1.6
 scene.camera.look_at(target)
 for frame in 3: await physics_frame
 var screen: Vector2 = scene.camera.unproject_position(target)
 var event := InputEventMouseButton.new()
 event.button_index = MOUSE_BUTTON_LEFT
 event.position = screen
 event.global_position = screen
 event.pressed = true
 Input.parse_input_event(event)
 await process_frame
 event = event.duplicate()
 event.pressed = false
 Input.parse_input_event(event)
 return true
func gump_reply(value: Dictionary, button: int) -> bool:
 if not visual: return session.respond_gump(value,button)
 for control in root.find_children("*","Control",true,false):
  if control.get_script() != preload("res://Network/GumpView.gd"): continue
  if int(control.data.serial) != int(value.serial): continue
  for reply in control.reply_buttons:
   if int(reply.get_meta("native_button",-1)) != button: continue
   var event := InputEventMouseButton.new()
   event.button_index = MOUSE_BUTTON_LEFT
   event.position = reply.get_global_rect().get_center()
   event.global_position = event.position
   event.pressed = true
   Input.parse_input_event(event)
   await process_frame
   event = event.duplicate()
   event.pressed = false
   Input.parse_input_event(event)
   await process_frame
   return true
 return false
func capture(name: String,item: Dictionary) -> void:
 if not visual: return
 scene.set_process(false)
 scene.camera.reparent(scene)
 var center: Vector3 = scene.entity_point(int(item.x),int(item.y),int(item.z))
 scene.camera.position = center+Vector3(2.8,2.2,3.3)
 scene.camera.look_at(center+Vector3(0,1.3,0))
 for frame in 24: await process_frame
 await RenderingServer.frame_post_draw
 var path := ProjectSettings.globalize_path("res://../outputs/validation/server-items-"+name+".png")
 root.get_texture().get_image().save_png(path)
 print("WORLD ITEM CAPTURE: ",name)
func run() -> void:
 visual = "--visual" in OS.get_cmdline_user_args()
 if visual:
  scene = load("res://Main.tscn").instantiate()
  root.add_child(scene)
  scene.accept_player_input = false
  session = scene.game
 else:
  session = preload("res://Network/GameSession.gd").new()
  root.add_child(session)
 session.failed.connect(func(reason: String): error = reason)
 session.message_received.connect(func(message: String):
  if message.begins_with("UCPOP1|"):
   var values := message.split("|")
   repeat_created = int(values[1])+int(values[2])+int(values[3])
  elif not message.begins_with("UC"): print("NATIVE ITEM REPLY: ",message))
 session.book_received.connect(func(book: Dictionary):
  if not book.get("pages",{}).is_empty(): book_pages = book)
 session.board_received.connect(func(board: Dictionary): board_name = board.title)
 session.gump_received.connect(func(gump: Dictionary): native_gump = gump)
 session.message_received.connect(func(message: String):
  if " rolls " in message: rolled = true)
 session.container_opened.connect(func(serial: int): opened = serial)
 session.container_contents_received.connect(func(serial: int, items: Array):
  if serial == opened: received_contents = items.size())
 session.item_label_received.connect(func(serial: int,label: String):
  if serial == sign_serial: sign_text = label)
 session.position_reset.connect(func(position: Dictionary): home = position.x == 1602 and position.y == 1591 and position.z == 20)
 session.connect_account(OS.get_environment("UO_DEV_USER"),OS.get_environment("UO_DEV_PASSWORD"))
 if not await until(func(): return session.phase == "characters"):
  fail("Character list timeout")
  return
 var selected := false
 for character in session.characters:
  if not character.name.is_empty():
   session.select_character(character.slot,character.name)
   selected = true
   break
 if not selected or not await until(func(): return session.phase == "world"):
  fail("Real character entry failed")
  return
 var path := ProjectSettings.globalize_path("res://../Server/runtime/Data/UltimaClonePreview/audit.local.json")
 var audit: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
 var definitions: Dictionary = audit.definitions
 var door := {}
 var single := {}
 var container := {}
 var empty := {}
 var sign := {}
 # The audit spans the whole city; reference fixtures stay in the original crop.
 var crop := Rect2i(1576,1568,64,64)
 for item in audit.items:
  if not crop.has_point(Vector2i(int(item.x),int(item.y))): continue
  if item.family == "door" and item.linked != null and int(item.z) == 0 and int(item.x) < 1620: door = item
  if item.family == "door" and item.linked == null and int(item.z) == 20: single = item
  if item.contents > 0 and item.type == "LibraryBookcase": container = item
  if item.contents == 0 and item.family == "drawers": empty = item
  if item.family == "sign" and int(item.z) == 0: sign = item
 if door.is_empty() or container.is_empty() or sign.is_empty() or empty.is_empty():
  fail("Expected native door/container/sign fixtures missing")
  return
 if not await visit(door):
  fail("Could not approach native door")
  return
 var rule: Dictionary = definitions[str(int(door.id))]
 var closed_id := int(rule.closed_id)
 var open_id := int(rule.opened_id)
 if int(session.world_items[int(door.serial)].id) != closed_id:
  await interact(door)
  if not await until(func(): return session.world_items.has(int(door.serial)) and int(session.world_items[int(door.serial)].id) == closed_id):
   fail("Initial door close not confirmed")
   return
  await create_timer(1.1).timeout
 await capture("door-closed",door)
 await interact(door)
 if not await until(func(): return session.world_items.has(int(door.serial)) and int(session.world_items[int(door.serial)].id) == open_id):
  fail("Native door open update missing")
  return
 var partner := int(door.linked)
 if not await until(func(): return session.world_items.has(partner) and int(session.world_items[partner].id) == int(definitions[str(int(session.world_items[partner].id))].opened_id)):
  fail("Linked second door failed to open")
  return
 print("WORLD ITEMS LIVE PASS: both native linked door leaves opened from one use")
 session.send_command("[PreviewPopulate")
 if not await until(func(): return repeat_created >= 0,30.0) or repeat_created != 0 or int(session.world_items[int(door.serial)].id) != open_id:
  fail("Population duplicated or reset an open native door")
  return
 print("WORLD ITEMS LIVE PASS: repeat population preserves open doors and creates zero duplicates")
 await capture("door-open",door)
 await create_timer(1.1).timeout
 await interact(door)
 if not await until(func(): return session.world_items.has(int(door.serial)) and int(session.world_items[int(door.serial)].id) == closed_id):
  fail("Native door close update missing")
  return
 print("WORLD ITEMS LIVE PASS: door close confirmed")
 if not await visit(container):
  fail("Could not approach native container")
  return
 await create_timer(1.1).timeout
 await interact(container)
 if not await until(func(): return opened == int(container.serial) and received_contents > 0):
  fail("Native populated container contents missing")
  return
 print("WORLD ITEMS LIVE PASS: native library container opened; ",received_contents," real entries")
 await capture("container",container)
 var book_serial := 0
 for entry in session.container_items.values():
  if int(entry.id) in [4079,4080,4081,4082,4083,4084]: book_serial = int(entry.serial); break
 if book_serial == 0:
  fail("Library has no native readable book")
  return
 await create_timer(1.1).timeout
 session.use_item(book_serial)
 if not await until(func(): return not book_pages.is_empty()):
  fail("Native book pages missing")
  return
 print("WORLD ITEMS LIVE PASS: native book title and ",book_pages.pages.size()," readable server pages")
 await capture("book",container)
 opened = 0
 received_contents = -1
 if not await visit(empty):
  fail("Could not approach empty native container")
  return
 await create_timer(1.1).timeout
 await interact(empty)
 if not await until(func(): return opened == int(empty.serial) and received_contents == 0):
  fail("Native empty container confirmation missing")
  return
 print("WORLD ITEMS LIVE PASS: empty native drawer confirmed without stale contents")
 if single.is_empty() or not await visit(single):
  fail("Could not approach native single door")
  return
 var single_rule: Dictionary = definitions[str(int(single.id))]
 await create_timer(1.1).timeout
 if int(session.world_items[int(single.serial)].id) != int(single_rule.closed_id):
  await interact(single)
  if not await until(func(): return int(session.world_items[int(single.serial)].id) == int(single_rule.closed_id)):
   fail("Single door initial close failed")
   return
  await create_timer(1.1).timeout
 await capture("single-door",single)
 await interact(single)
 if not await until(func(): return int(session.world_items[int(single.serial)].id) == int(single_rule.opened_id)):
  fail("Single door open failed")
  return
 # Approach the opened leaf from its current server position so the jamb
 # does not obscure a real mouse click from the initial diagonal stand point.
 if not await visit(single):
  fail("Could not approach the open single leaf")
  return
 await create_timer(1.1).timeout
 await interact(single)
 if not await until(func(): return int(session.world_items[int(single.serial)].id) == int(single_rule.closed_id)):
  fail("Single door close failed")
  return
 print("WORLD ITEMS LIVE PASS: native single door opens/closes independently")
 if not await visit(sign):
  fail("Could not approach native sign")
  return
 sign_serial = int(sign.serial)
 await create_timer(1.1).timeout
 await interact(sign)
 if not await until(func(): return not sign_text.is_empty()):
  fail("Native sign name missing")
  return
 if sign_text.begins_with("Server label #"):
  fail("Native sign label was not localized")
  return
 print("WORLD ITEMS LIVE PASS: clicked native sign name: ",sign_text)
 await capture("sign",sign)
 var dice := {}
 var board := {}
 for item in audit.items:
  if item.type == "Dices": dice = item
  if item.type == "BulletinBoard": board = item
 if dice.is_empty() or not await visit(dice):
  fail("Dice fixture not reachable")
  return
 await create_timer(1.1).timeout
 session.use_item(int(dice.serial))
 if not await until(func(): return rolled):
  fail("Native dice script did not return a roll")
  return
 print("WORLD ITEMS LIVE PASS: native dice script returned server roll")
 if board.is_empty() or not await visit(board):
  fail("Bulletin board fixture not reachable")
  return
 await create_timer(1.1).timeout
 session.use_item(int(board.serial))
 if not await until(func(): return not board_name.is_empty()):
  fail("Native bulletin board display missing")
  return
 print("WORLD ITEMS LIVE PASS: native bulletin board opened: ",board_name)
 await capture("board",board)
 session.request_help()
 if not await until(func(): return not native_gump.is_empty()):
  fail("Native compressed Help gump missing")
  return
 print("WORLD ITEMS LIVE PASS: native compressed Help gump, ",native_gump.commands.size()," controls")
 await capture("gump-help",board)
 var help_gump := native_gump
 native_gump = {}
 if not await gump_reply(help_gump,1):
  fail("Native Help option response failed")
  return
 if not await until(func(): return not native_gump.is_empty()):
  fail("Native Help callback did not open description form")
  return
 var has_entry := false
 for command in native_gump.commands:
  if command[0] == "textentry": has_entry = true
 if not has_entry:
  fail("Help callback did not provide native text entry")
  return
 print("WORLD ITEMS LIVE PASS: native Help option executes server script and opens text-entry gump")
 await capture("gump-description",board)
 if not await gump_reply(native_gump,0):
  fail("Native gump cancel response failed")
  return
 session.return_to_britain()
 if not await until(func(): return home):
  fail("Development character return home failed")
  return
 session.close()
 if scene: scene.free()
 else: session.free()
 for frame in 4: await process_frame
 print("WORLD ITEMS LIVE: all interactions passed; development character returned home")
 quit()
