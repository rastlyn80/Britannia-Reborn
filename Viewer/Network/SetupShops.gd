extends SceneTree
var session: Node
var reply := ""
var error := ""
func _initialize() -> void: call_deferred("run")
func until(condition: Callable) -> bool:
 var start := Time.get_ticks_msec()
 while not condition.call():
  if not error.is_empty() or Time.get_ticks_msec()-start>10000: return false
  await process_frame
 return true
func run() -> void:
 session=preload("res://Network/GameSession.gd").new()
 root.add_child(session)
 session.failed.connect(func(text: String): error=text)
 session.message_received.connect(func(text: String):
  if text.begins_with("UCSHOP1|") or text.begins_with("UCINN1|") or text.begins_with("No native tavern") or "source position is blocked" in text: reply=text)
 session.connect_account(OS.get_environment("UO_DEV_USER"),OS.get_environment("UO_DEV_PASSWORD"))
 if await until(func(): return session.phase=="characters"):
  for character in session.characters:
   if not character.name.is_empty(): session.select_character(character.slot,character.name);break
 if not await until(func(): return session.phase=="world"):
  push_error("Shop setup needs an existing development character: "+error)
  session.close();quit(1);return
 for command in ["[PreviewShop","[PreviewInn"]:
  reply=""
  session.send_command(command)
  if not await until(func(): return not reply.is_empty()):
   push_error("Native shop helper unavailable; install the extension and restart the server. "+error)
   session.close();quit(1);return
  print("NATIVE SHOP SETUP: ",reply)
 session.close()
 session.free()
 for frame in 3: await process_frame
 quit()
