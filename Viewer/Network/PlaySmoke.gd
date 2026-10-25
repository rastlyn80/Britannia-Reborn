extends SceneTree
# Tests the populated native world, using a known closed door instead of a
# hard-coded walking route whose endpoint changes as the world is populated.
var client: Node
var error := ""
var result := -1
var inventory := false
func _initialize() -> void: call_deferred("run")
func until(condition: Callable, seconds: float = 8.0) -> bool:
 var start := Time.get_ticks_msec()
 while not condition.call():
  if not error.is_empty() or Time.get_ticks_msec()-start > seconds*1000: return false
  await process_frame
 return true
func fail(reason: String) -> void:
 push_error(reason+" "+error)
 client.close()
 quit(1)
func step(direction: int) -> int:
 if not await until(func(): return client.outstanding == -1 and not client.awaiting_position): return -1
 while not client.walk(direction): await process_frame
 result = -1
 if not await until(func(): return result != -1): return -1
 return result
func run() -> void:
 client = preload("res://Network/GameSession.gd").new()
 root.add_child(client)
 client.failed.connect(func(reason: String): error = reason)
 client.movement_result.connect(func(accepted: bool,_position: Dictionary): result = 1 if accepted else 0)
 client.inventory_received.connect(func(_items: Array): inventory = true)
 client.connect_account(OS.get_environment("UO_DEV_USER"),OS.get_environment("UO_DEV_PASSWORD"))
 if not await until(func(): return client.phase == "characters"):
  fail("Character list timeout")
  return
 for character in client.characters:
  if not character.name.is_empty():
   client.select_character(character.slot,character.name)
   break
 if not await until(func(): return client.phase == "world"):
  fail("World entry timeout")
  return
 client.open_backpack()
 if not await until(func(): return inventory):
  fail("Backpack contents missing")
  return
 var path := "res://../Server/runtime/Data/UltimaClonePreview/audit.local.json"
 if not FileAccess.file_exists(path):
  fail("Run Populate-Britain.cmd before the populated-world movement check")
  return
 var audit: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
 var door := {}
 for item in audit.items:
  if item.family == "door" and int(item.z) == 0:
   door = item
   break
 if door.is_empty():
  fail("No native door fixture")
  return
 client.send_command("[PreviewVisit %d" % int(door.serial))
 if not await until(func(): return client.world_items.has(int(door.serial)) and maxi(absi(client.player.x-int(door.x)),absi(client.player.y-int(door.y))) <= 2):
  fail("Could not approach native collision fixture")
  return
 var rule: Dictionary = audit.definitions[str(int(door.id))]
 if int(client.world_items[int(door.serial)].id) != int(rule.closed_id):
  await create_timer(1.1).timeout
  client.use_item(int(door.serial))
  if not await until(func(): return int(client.world_items[int(door.serial)].id) == int(rule.closed_id)):
   fail("Native door could not be closed")
   return
 var deltas := [Vector2i(0,-1),Vector2i(1,-1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1),Vector2i(-1,1),Vector2i(-1,0),Vector2i(-1,-1)]
 var rejected := false
 for attempt in 8:
  var delta := Vector2i(signi(int(door.x)-int(client.player.x)),signi(int(door.y)-int(client.player.y)))
  var direction := deltas.find(delta)
  if direction < 0: break
  if await step(direction) == 0:
   rejected = true
   break
 if not rejected:
  fail("Expected native closed-door rejection missing")
  return
 var blocked := Vector2i(client.player.x,client.player.y)
 var recovered := false
 for direction in 8:
  for attempt in 2:
   var accepted := await step(direction)
   if accepted == 1 and Vector2i(client.player.x,client.player.y) != blocked:
    recovered = true
    break
  if recovered: break
 if not recovered:
  fail("No accepted movement after native rejection")
  return
 client.return_to_britain()
 if not await until(func(): return client.player.x == 1602 and client.player.y == 1591 and client.player.z == 20):
  fail("Return home failed")
  return
 print("PLAY SMOKE PASSED: real entry, backpack, native closed-door rejection, accepted movement and exact position recovery; returned home")
 client.close()
 client.free()
 for frame in 3: await process_frame
 quit()
