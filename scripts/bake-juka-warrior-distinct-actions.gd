extends "res://../scripts/bake-zombie-actions.gd"

func run() -> void:
	var base := Registry.entry(764)
	var row := base.duplicate(true)
	row.assets = {}
	for treatment: String in ["original","rounded","modern"]:
		row.assets[treatment] = Registry.asset_path(base,treatment)
	Registry.entries[764] = row
	bake_body(764,"juka-warrior-distinct",{6:"StepSlash",15:"JukaStagger",18:"JukaShoulderCheck"},
		["bake-juka-warrior-distinct-actions.gd", "bake-zombie-actions.gd"])
	quit()

func pose_troll(rig: Skeleton3D, slot: int, phase: float) -> void:
	var brace := smoothstep(0.03,0.27,phase)*(1.0-smoothstep(0.38,0.75,phase))
	var follow := smoothstep(0.23,0.60,phase)*(1.0-smoothstep(0.71,1.0,phase))
	match slot:
		6:
			turn_world(rig,"bip01 spine1",Vector3.UP,0.44*brace-0.55*follow)
			turn_world(rig,"bip01 spine2",Vector3.RIGHT,0.31*follow)
			turn_world(rig,"bip01 r upperarm",Vector3.RIGHT,0.30*brace-1.07*follow)
			turn_world(rig,"bip01 r forearm",Vector3.RIGHT,-0.29*brace+0.24*follow)
			turn_world(rig,"bip01 l upperarm",Vector3.RIGHT,-0.34*brace)
			turn_world(rig,"bip01 l thigh",Vector3.RIGHT,-0.39*follow)
			turn_world(rig,"bip01 l calf",Vector3.RIGHT,0.31*follow)
		15:
			turn_world(rig,"bip01 spine1",Vector3.FORWARD,-0.34*brace)
			turn_world(rig,"bip01 spine2",Vector3.RIGHT,0.24*brace)
			turn_world(rig,"bip01 head",Vector3.UP,0.24*follow)
			turn_world(rig,"bip01 r upperarm",Vector3.FORWARD,-0.44*brace)
			turn_world(rig,"bip01 l upperarm",Vector3.FORWARD,0.31*brace)
			turn_world(rig,"bip01 l thigh",Vector3.RIGHT,-0.19*brace)
			turn_world(rig,"bip01 l calf",Vector3.RIGHT,0.23*brace)
		18:
			turn_world(rig,"bip01 spine1",Vector3.RIGHT,0.17*follow)
			turn_world(rig,"bip01 spine2",Vector3.UP,-0.18*brace)
			turn_world(rig,"bip01 neck",Vector3.UP,0.39*brace-0.32*follow)
			turn_world(rig,"bip01 head",Vector3.RIGHT,0.19*follow)
			turn_world(rig,"bip01 r clavicle",Vector3.FORWARD,-0.15*brace)
