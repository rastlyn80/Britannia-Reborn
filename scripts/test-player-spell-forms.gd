# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Avatar := preload("res://Presentation/HumanAvatar.gd")
const Corpses := preload("res://Presentation/CorpseModels.gd")
const Wardrobe := preload("res://Presentation/HumanWardrobe.gd")
const FORMS := {744: 0x847e, 745: 0x847e, 746: 0, 747: 0, 748: 0x4001, 749: 0}

func _initialize() -> void:
	create_timer(45.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var catalogue := Corpses.catalogue()
	for body: int in FORMS:
		var avatar := Avatar.new()
		avatar.initial_body = 401 if body in [745, 747] else 400
		root.add_child(avatar)
		avatar.set_physics_process(false)
		var hue: int = FORMS[body]
		avatar.apply_server_appearance({"body": body, "hue": hue}, [])
		if Wardrobe.human(body):
			assert(avatar.human_visual.female == (body == 745))
			assert(avatar.human_visual.skin.get_shader_parameter("use_form_hue") == true)
		else:
			assert(avatar.horse_visual.native_body == body and avatar.horse_visual.native_hue == hue)
		assert(catalogue.any(func(entry: Dictionary): return int(entry.body) == body and int(entry.graphic) == 0x2006))
		var corpse := Corpses.build(body, hue)
		assert(corpse != null and corpse.get_meta("native_hue") == hue)
		assert(corpse.get_meta("static_cadaver") == true)
		corpse.free()
		avatar.apply_server_appearance({"body": avatar.initial_body, "hue": 1002}, [])
		assert(avatar.human_visual != null and avatar.human_visual.skin.get_shader_parameter("use_form_hue") == false)
		avatar.queue_free()
		await process_frame
	print("PLAYER SPELL FORM ROUTES: six models, reversions and static corpse identities")
	quit()
