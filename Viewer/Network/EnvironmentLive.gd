extends SceneTree
var session := preload("res://Network/GameSession.gd").new()
var started := 0
var entered_world := false
func _initialize() -> void:
 started = Time.get_ticks_msec()
 root.add_child(session)
 session.failed.connect(func(reason: String):
  push_error(reason)
  quit(1))
 session.characters_received.connect(func(characters: Array,_cities: Array):
  for character in characters:
   if not character.name.is_empty():
    session.select_character(character.slot,character.name)
    return
  push_error("No existing development character")
  quit(1))
 session.entered.connect(func(_position: Dictionary): entered_world = true)
 session.environment_changed.connect(func(state: Dictionary):
  if entered_world and state.has("minute_of_day") and state.has("global_light") and state.has("weather_type") and state.has("personal_light"):
   print("ENVIRONMENT LIVE PASS: real character entered; server regional minute ",state.minute_of_day,"; seconds/minute ",state.seconds_per_minute,"; global/personal light ",state.global_light,"/",state.personal_light,"; weather type/density ",state.weather_type,"/",state.density)
   session.call_deferred("close")
   call_deferred("quit",0))
 session.connect_account(OS.get_environment("UO_DEV_USER"),OS.get_environment("UO_DEV_PASSWORD"))
func _process(_delta: float) -> bool:
 if Time.get_ticks_msec()-started > 25000:
  push_error("Live server environment snapshot timeout")
  session.close()
  quit(1)
 return false
