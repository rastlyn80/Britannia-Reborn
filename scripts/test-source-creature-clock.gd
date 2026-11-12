# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Manual := AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
const Forms := {
	21: "giant-serpent-enhanced/",
	92: "silver-serpent-enhanced/",
	150: "sea-serpent-enhanced/",
	238: "ordinary-rat-enhanced/",
	780: "enhanced-creature-actions/780-",
}


func _initialize() -> void:
	create_timer(25.0).timeout.connect(func(): quit(2))
	run.call_deferred()


func run() -> void:
	var world := (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	world.game.set_process(false)
	var enhanced := "--enhanced-creature-actions" in OS.get_cmdline_user_args()
	if world.enhanced_creature_actions != enhanced:
		push_error("Prepared scene clock test received an unexpected client profile.")
		quit(1)
		return
	var forms := Forms if enhanced else {780: "bog-thing-actions.scn"}
	var seen := {}
	var active: Array[Node3D] = []
	for body: int in forms:
		for treatment: String in ["modern", "rounded", "original"]:
			var path := Registry.asset_path(Registry.entry(body), treatment)
			if seen.has(path) or not path.contains(forms[body]) or not ResourceLoader.exists(path, "PackedScene"):
				continue
			seen[path] = true
			var actor := Registry.create(body)
			actor.treatment = treatment
			root.add_child(actor)
			actor.set_physics_process(false)
			if actor.model.scene_file_path != path or actor.animator.callback_mode_process == Manual:
				push_error("Prepared creature did not select its running scene clock: " + path)
				quit(1)
				return
			actor.apply_identity(body, 0x8035)
			actor.animator.play("Walk", 0.0)
			actor.animator.seek(0.0)
			active.append(actor)
	await create_timer(.18).timeout
	for actor: Node3D in active:
		if actor.animator.current_animation_position <= .06:
			push_error("Packed animation did not advance naturally: " + actor.model.scene_file_path)
			quit(1)
			return
		print("SOURCE CREATURE CLOCK: ", actor.native_body, " ", actor.treatment,
			" advanced ", actor.animator.current_animation_position, " seconds")
		actor.free()
	print("SOURCE CREATURE CLOCK: ", active.size(), " prepared scenes advanced; Enhanced ", enhanced)
	quit()
