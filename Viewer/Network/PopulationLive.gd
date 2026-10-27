extends SceneTree
var session := preload("res://Network/GameSession.gd").new()
var stage := "first"
var initial := {}
var first := {}
var started := 0
func audit(file: String) -> Dictionary:
 var path := ProjectSettings.globalize_path("res://../Server/runtime/Data/UltimaClonePreview/"+file)
 var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
 return parsed if parsed is Dictionary else {}
func _initialize() -> void:
 started = Time.get_ticks_msec()
 root.add_child(session)
 session.failed.connect(func(reason: String): fail(reason))
 session.characters_received.connect(func(characters: Array,_cities: Array):
  for character in characters:
   if not character.name.is_empty():
    session.select_character(character.slot,character.name)
    return
  fail("Create a development character first"))
 session.entered.connect(func(_position: Dictionary): session.send_command("[PreviewPopulate"))
 session.message_received.connect(receive)
 session.connect_account(OS.get_environment("UO_DEV_USER"),OS.get_environment("UO_DEV_PASSWORD"))
func fail(reason: String) -> void:
 push_error(reason)
 session.close()
 quit(1)
func receive(message: String) -> void:
 if message.begins_with("Population stopped:"):
  fail(message)
  return
 if not message.begins_with("UCPOP1|"): return
 var counts := message.split("|")
 if stage == "first":
  initial = audit("audit-before.local.json")
  first = audit("audit.local.json")
  if initial.is_empty() or first.is_empty():
   fail("Missing native population audits")
   return
  var after_serials := {}
  for item in first.items: after_serials[int(item.serial)] = item
  for item in initial.items:
   if not after_serials.has(int(item.serial)):
    fail("Population removed an existing root item")
    return
  print("POPULATION LIVE: created decorations/doors/signs ",counts[1],"/",counts[2],"/",counts[3],"; previous root items preserved")
  stage = "repeat"
  session.send_command("[PreviewPopulate")
 else:
  if int(counts[1])+int(counts[2])+int(counts[3]) != 0:
   fail("Repeated population created duplicates")
   return
  var again := audit("audit.local.json")
  var serials := {}
  for item in again.items: serials[int(item.serial)] = true
  if again.items.size() != first.items.size():
   fail("Repeated population changed root item count")
   return
  for item in first.items:
   if not serials.has(int(item.serial)):
    fail("Repeated population replaced an existing item")
    return
  var families := {}
  for item in again.items: families[item.family] = int(families.get(item.family,0))+1
  if families.get("door",0) == 0 or families.get("sign",0) == 0:
   fail("Population lacks doors or signs")
   return
  var output := ProjectSettings.globalize_path("res://../outputs/validation/population-check.json")
  DirAccess.make_dir_recursive_absolute(output.get_base_dir())
  var file := FileAccess.open(output,FileAccess.WRITE)
  file.store_string(JSON.stringify({"before_root_items":initial.items.size(),"after_root_items":again.items.size(),"families":families,"repeat_created":0,"preserved_existing":true},"  "))
  file.close()
  print("POPULATION LIVE PASS: ",again.items.size()," root items; repeat created zero; ",families)
  session.close()
  quit()
func _process(_delta: float) -> bool:
 if Time.get_ticks_msec()-started > 180000: fail("Population response timed out")
 return false
