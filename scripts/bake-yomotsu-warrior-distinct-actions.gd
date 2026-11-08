extends "res://../scripts/bake-zombie-actions.gd"

func run() -> void:
	var row := Registry.entry(245)
	assert(row.classic_action_categories["11"] == "Fidget")
	bake_body(245,"yomotsu-warrior-distinct",{15:"YomotsuRecoil",18:"WeaponRest"},
		["bake-yomotsu-warrior-distinct-actions.gd", "bake-zombie-actions.gd"])
	quit()

func pose_troll(rig: Skeleton3D, slot: int, phase: float) -> void:
	var pulse := smoothstep(0.04,0.35,phase)*(1.0-smoothstep(0.55,1.0,phase))
	var recoil := slot == 15
	turn_world(rig,"bip01 spine1",Vector3.RIGHT,(-0.22 if recoil else -0.09)*pulse)
	turn_world(rig,"bip01 spine2",Vector3.UP,(0.14 if recoil else -0.23)*pulse)
	turn_world(rig,"bip01 head",Vector3.RIGHT,(-0.16 if recoil else 0.15)*pulse)
	turn_world(rig,"bip01 r upperarm",Vector3.RIGHT,(-0.44 if recoil else 0.29)*pulse)
	turn_world(rig,"bip01 r forearm",Vector3.RIGHT,(-0.24 if recoil else -0.11)*pulse)
	turn_world(rig,"bip01 l clavicle",Vector3.UP,0.12*pulse)
	turn_world(rig,"bone01",Vector3.RIGHT,0.11*pulse)
