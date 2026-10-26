extends SceneTree
const Game = preload("res://Network/GameSession.gd")
const Rig = preload("res://Presentation/LightingRig.gd")
var checks := 0
var failures := 0
func check(ok: bool, description: String) -> void:
 checks += 1
 if ok: print("PASS ",description)
 else:
  failures += 1
  push_error(description)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var game := Game.new()
 root.add_child(game)
 game.set_process(false)
 game.player.serial = 7
 var events := []
 game.environment_changed.connect(func(state: Dictionary): events.append(state))
 for byte in PackedByteArray([0x4f,12,0x65,2,70,241]): game.feed(PackedByteArray([byte]))
 check(events.size() == 2 and game.environment_state.global_light == 12,"fragmented/coalesced native global light and weather")
 check(game.environment_state.temperature == -15 and game.environment_state.weather_type == 2,"snow and signed weather temperature")
 game.feed(PackedByteArray([0x4e,0,0,0,8,20]))
 check(not game.environment_state.has("personal_light"),"other mobile's personal light ignored")
 game.feed(PackedByteArray([0x4e,0,0,0,7,9]))
 check(game.environment_state.personal_light == 9,"own personal light kept separate from global daylight")
 game._server_text("UCENV1|23|59|5",true)
 var sample: Dictionary = game.environment_state.duplicate()
 check(is_equal_approx(Rig.regional_minute(sample,sample.sample_msec+10000),1.0),"server clock crosses midnight at upstream five-second minute rate")
 check(is_equal_approx(Rig.regional_minute(sample,sample.sample_msec+999999),5.0),"missing clock snapshots freeze extrapolation after 30 seconds")
 var before := events.size()
 game._server_text("UCENV1|99|0|5",true)
 game._server_text("UCENV1|12|0|0",true)
 game._server_text("UCENV1|bad|0|5",true)
 game._server_text("UCENV1|12|0|5")
 check(events.size() == before,"invalid clock payloads and player speech cannot update sky")
 check(Rig.weather_amount(sample) == 1.0,"server density controls precipitation amount")
 game.feed(PackedByteArray([0x65,0xfe,0,15]))
 check(Rig.weather_amount(game.environment_state) == 0.0,"native FE weather clear stops precipitation")
 game.feed(PackedByteArray([0x65,0xff,70,15]))
 check(Rig.weather_amount(game.environment_state) == 0.0,"FF and unknown weather cannot invent rain")
 game.close()
 check(game.environment_state.is_empty(),"disconnect clears authoritative environment state")
 game.free()
 var rig := Rig.new()
 root.add_child(rig)
 rig.configure(rig,{},null,true)
 rig._apply_atmosphere(60.0,0.0,12.0,0.0)
 var night := rig.sun.light_energy
 rig._apply_atmosphere(720.0,0.0,0.0,0.0)
 var day := rig.sun.light_energy
 rig._apply_atmosphere(720.0,1.0,0.0,0.0)
 check(night < 0.01 and day > 1.0 and rig.sun.light_energy < day,"server night and storms reduce sunlight")
 rig.reset_server_environment()
 check(is_equal_approx(rig.visual_minute,900.0) and rig.server_environment.is_empty(),"offline preview restores deterministic afternoon")
 var night_state := {"minute_of_day":60,"seconds_per_minute":5,"global_light":26,"sample_msec":0}
 rig.sky_mode = "day"
 check(is_equal_approx(rig.presented_minute(night_state,0),900.0) and is_equal_approx(rig.presented_light(night_state),0.0),"always-day view shows afternoon at full light during server night")
 rig.sky_mode = "night"
 check(is_equal_approx(rig.presented_minute({"minute_of_day":840,"seconds_per_minute":5,"sample_msec":0},0),0.0),"always-night view shows midnight during server day")
 rig.sky_mode = ""
 check(is_equal_approx(rig.presented_minute(night_state,0),60.0) and is_equal_approx(rig.presented_light(night_state),26.0) and night_state.minute_of_day == 60,"server-time view follows the server; overrides never alter server state")
 rig.free()
 print("ENVIRONMENT CHECKS: %d passed / %d total" % [checks-failures,checks])
 quit(0 if failures == 0 else 1)
