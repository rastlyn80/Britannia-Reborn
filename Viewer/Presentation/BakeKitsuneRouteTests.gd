extends SceneTree

const Registry = preload("res://Presentation/CreatureRegistry.gd")
const Avatar = preload("res://Presentation/HumanAvatar.gd")
const Corpses = preload("res://Presentation/CorpseModels.gd")
const BODY := 246
const PACKAGE := "res://local-art/creatures/bake_kitsune/preparation.json"
const ACTIONS := {3: "Eat", 4: "Alert", 5: "Attack", 6: "Attack2", 7: "Hit",
	9: "Fidget", 11: "LieDown", 12: "Death2"}


func _initialize() -> void:
	create_timer(15.0).timeout.connect(func(): quit(2))
	call_deferred("run")


func run() -> void:
	Registry.load_index()
	if "--prepared" in OS.get_cmdline_user_args():
		var package: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PACKAGE))
		Registry.entries[BODY] = package.models[0]
	assert(Registry.supports_body(BODY))
	assert(Registry.entry(BODY).kind == "kitsun_tsuki")
	var avatar := Avatar.new()
	avatar.initial_body = BODY
	root.add_child(avatar)
	avatar.set_physics_process(false)
	var actor: Node3D = avatar.horse_visual
	assert(actor != null and actor.action_profile == "animal")
	actor.set_physics_process(false)
	assert(actor.contact.align_skinned_soles and actor.contact.feet.size() == 4)
	assert(actor.skeleton.get_bone_count() >= 37)
	for name in Registry.entry(BODY).retained_weighted_helper_joints:
		assert(actor.skeleton.find_bone(name) >= 0)
	for group: int in ACTIONS:
		assert(avatar.receive_native_action({"protocol": "classic", "action": group}))
		assert(actor.current_clip == ACTIONS[group])
	for hue in [0, 53, 0x8035]:
		var corpse := Corpses.build(BODY, hue)
		assert(corpse != null and corpse.get_meta("static_cadaver"))
		assert(corpse.get_meta("corpse_body") == BODY and corpse.get_meta("native_hue") == hue)
		assert(corpse.find_children("*", "AnimationPlayer", true, false).is_empty())
		corpse.free()
	avatar.free()
	print("kitsun_tsuki passed eight classic actions, four sole probes and three static corpse hues")
	quit()
