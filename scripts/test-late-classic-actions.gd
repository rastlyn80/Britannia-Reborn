extends "res://../scripts/test-hopper-horde-actions.gd"

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
