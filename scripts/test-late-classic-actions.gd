extends "res://../scripts/test-hopper-horde-actions.gd"

func run() -> void:
	Registry.load_index()
	var current := Registry.entry(172)
	if current.get("classic_gesture_batch") == "related_champion_actions":
		Registry.entries[172] = preload("res://Presentation/SealedCreatureActionBase.gd").retained(current, 172)
	await super.run()

func specifications() -> Dictionary:
	return {
		303: ["devourer_lion_hiryu/devourer", "DevourerMouthCheck", "bone_lrip04"],
		172: ["champions/dragons_dragon_retro_red", "RikktorTailCheck", "bip01 tail3"],
		311: ["aos_armed/shadow_knight", "ShadowKnightGlance", "bip01 l hand"],
	}

func batch_name() -> String:
	return "late_classic_actions"

func passes_pose(body: int, gap: float, displacement: float, rotation: float, idle_gap: float) -> bool:
	if body == 172:
		# Rikktor's existing foot solver has a small slope gap in Idle.
		return gap >= minf(-0.025, idle_gap - 0.004) and displacement > 1.0
	return gap >= -0.025 and (rotation > 0.12 if body == 303 else displacement > 0.18)
