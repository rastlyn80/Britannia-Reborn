# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Motion := preload("res://Presentation/DappleHorseMotion.gd")
const Body := 226
const Combat := 0x40
const Protocol := "new"


func _initialize() -> void:
	var checks := 0
	var steady := {0: 4, 2: 15, 4: 10, 8: 28, 14: 25, 15: 25}
	for body in [200, 204, 226, 228]:
		for variant in range(128):
			for flags in [0, Combat]:
				for type: int in steady:
					if not check_group(body, type, flags, variant, steady[type]):
						return
					checks += 1
				if not check_group(body, 3, flags, variant, [2, 3][variant % 2]):
					return
				if not check_group(body, 11, flags, variant, 12 if body in [200, 226] else 4):
					return
				if not check_group(body, 1, flags, variant, 15 if body == 226 else -1):
					return
				checks += 3
			var peaceful: int = [1, 1, 26][variant % 3] if body == 226 else 26
			var combat: int = 27 if body == 226 else [26, 27][variant % 2]
			if not check_group(body, 5, 0, variant, peaceful) or not check_group(body, 5, Combat, variant, combat):
				return
			checks += 2
	var valid := {"protocol": Protocol, "body": Body, "type": 3, "variation": 1}
	for invalid: Dictionary in [{"protocol": "classic"}, {"variation": 255}, {"variation": -1}, {"type": 7}, {"body": 200}]:
		if not Motion.select_action(valid.merged(invalid, true), Body, Combat).is_empty():
			fail("accepted invalid action: %s" % [invalid])
			return
		checks += 1
	if not Motion.select_action(valid, 205, Combat).is_empty() or not Motion.select_action(valid, Body, -1).is_empty():
		fail("accepted other horse identity or missing mode")
		return
	checks += 2
	print("ORDINARY HORSE ACTION SELECTION: ", checks, " checks")
	quit()


func check_group(body: int, type: int, flags: int, variant: int, expected: int) -> bool:
	var packet := {"protocol": Protocol, "body": body, "type": type, "subaction": 0, "variation": variant}
	var result := Motion.select_action(packet, body, flags)
	if result.get("group", -1) != expected or bool(result.get("death", false)) != (type == 3):
		fail("body %d, group %d, flags %d, variant %d: %s" % [body, expected, flags, variant, result])
		return false
	return true


func fail(message: String) -> void:
	printerr(message)
	quit(1)
