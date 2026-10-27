extends SceneTree
# Live character sheet checks against the local ModernUO server: native status
# and skill list, a skill lock round trip (re-queried, then restored) and a
# usable skill opening the server's target cursor. --visual also opens the
# real sheet in the game scene and saves screenshots (--sheet-shot=PATH stem).
var scene: Node3D
var session: Node
var error := ""
func _initialize() -> void: call_deferred("run")
func until(condition: Callable,seconds: float = 10.0) -> bool:
 var start := Time.get_ticks_msec()
 while not condition.call():
  if not error.is_empty() or Time.get_ticks_msec()-start > seconds*1000: return false
  await process_frame
 return true
func fail(reason: String) -> void:
 push_error(reason+" "+error)
 if session: session.close()
 quit(1)
func run() -> void:
 var visual := "--visual" in OS.get_cmdline_user_args()
 var shot := ""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--sheet-shot="): shot = arg.substr(13)
 if visual:
  scene = load("res://Main.tscn").instantiate()
  root.add_child(scene)
  scene.accept_player_input = false
  session = scene.game
 else:
  session = preload("res://Network/GameSession.gd").new()
  root.add_child(session)
 session.failed.connect(func(reason: String): error = reason)
 session.message_received.connect(func(text: String): print("SERVER: ",text))
 session.connect_account(OS.get_environment("UO_DEV_USER"),OS.get_environment("UO_DEV_PASSWORD"))
 if not await until(func(): return session.phase == "characters"):
  fail("Character list timeout")
  return
 for character in session.characters:
  if not character.name.is_empty():
   session.select_character(character.slot,character.name)
   break
 if not await until(func(): return session.phase == "world"):
  fail("Real character entry failed")
  return
 if not await until(func(): return session.player_status.has("str") and session.skills.size() == 58):
  fail("Native status/skills not received (status %s, %d skills)" % [str(session.player_status.keys()),session.skills.size()])
  return
 var s: Dictionary = session.player_status
 print("NATIVE STATUS: %s v%d str %d dex %d int %d hits %d/%d stam %d/%d mana %d/%d gold %d weight %d/%d cap %d locks %s" % [s.name,s.version,s.str,s.dex,s.int,s.hits,s.hits_max,s.stam,s.stam_max,s.mana,s.mana_max,s.gold,s.weight,s.get("weight_max",0),s.get("stat_cap",0),str(s.get("locks",{}))])
 if int(s.str) <= 0 or int(s.hits_max) <= 0:
  fail("Implausible native status")
  return
 # Lock round trip on Magery: change, re-query the server's list, restore.
 var original := int(session.skills[25].lock)
 var changed := (original+1)%3
 session.set_skill_lock(25,changed)
 await create_timer(0.5).timeout
 session.skills.clear()
 session.request_character()
 if not await until(func(): return session.skills.size() == 58) or int(session.skills[25].lock) != changed:
  fail("Skill lock was not applied by the server")
  return
 session.set_skill_lock(25,original)
 await create_timer(0.5).timeout
 session.skills.clear()
 session.request_character()
 if not await until(func(): return session.skills.size() == 58) or int(session.skills[25].lock) != original:
  fail("Skill lock was not restored")
  return
 print("NATIVE SKILL LOCK: Magery %d -> %d -> %d confirmed by re-query" % [original,changed,original])
 # Anatomy asks for a target; cancel it again.
 var seen := {"target":false}
 session.target_changed.connect(func(active: bool): if active: seen.target = true)
 session.use_skill(1)
 if not await until(func(): return seen.target):
  fail("Using Anatomy did not open a native target cursor")
  return
 session.target_item()
 print("NATIVE SKILL USE: Anatomy opened the server target cursor; cancelled")
 if visual:
  var sheet: Control = scene.character_sheet
  sheet.toggle("character")
  for i in 30: await process_frame
  await RenderingServer.frame_post_draw
  if not shot.is_empty(): root.get_texture().get_image().save_png(shot+"-character.png")
  sheet.toggle("skills")
  for i in 10: await process_frame
  await RenderingServer.frame_post_draw
  if not shot.is_empty(): root.get_texture().get_image().save_png(shot+"-skills.png")
 print("CHARACTER LIVE PASS: status, %d skills, lock round trip, skill use" % session.skills.size())
 session.close()
 quit(0)
