extends "res://../scripts/bake-zombie-actions.gd"

const ROUTES := {51:["slime",{18:"CrestRise"}],154:["mummy",{15:"MummyRecoil",18:"MummyCurl"}],
	80:["giant-toad",{6:"SpringLunge",15:"HindBrace",16:"BellyDuck",18:"ThroatPulse"}]}
var body: int

func run() -> void:
	for native_body: int in ROUTES:
		body = native_body
		var original := Registry.entry(body)
		var row := original.duplicate(true)
		row.assets = {}
		for treatment: String in ["original","rounded","modern"]:
			row.assets[treatment] = Registry.asset_path(original,treatment)
		Registry.entries[body] = row
		bake_body(body,ROUTES[body][0]+"-distinct",ROUTES[body][1],["bake-lowland-creature-gestures.gd", "bake-zombie-actions.gd"])
	quit()

func fit_troll(player: AnimationPlayer, rig: Skeleton3D, skins: Array[Dictionary], slot: int) -> Animation:
	var result := super.fit_troll(player,rig,skins,slot)
	if body != 80 or slot != 6:
		return result
	var node_path := player.get_node(player.root_node).get_path_to(rig)
	var track := result.find_track(NodePath("%s:bip01" % node_path),Animation.TYPE_POSITION_3D)
	var parent := rig.get_bone_parent(rig.find_bone("bip01"))
	var world_up := rig.get_bone_global_pose(parent).basis.inverse() * rig.global_basis.inverse() * Vector3.UP
	for index in result.track_get_key_count(track):
		var phase := result.track_get_key_time(track,index)/result.length
		var launch := smoothstep(0.12,0.39,phase)*(1.0-smoothstep(0.59,0.98,phase))
		var original: Vector3 = result.track_get_key_value(track,index)
		result.track_set_key_value(track,index,original + world_up * 0.14 * launch)
	return result

func pose_troll(rig: Skeleton3D, slot: int, phase: float) -> void:
	var pulse := smoothstep(0.03,0.33,phase)*(1.0-smoothstep(0.57,1.0,phase))
	var follow := smoothstep(0.27,0.63,phase)*(1.0-smoothstep(0.72,1.0,phase))
	match body:
		51:
			var rise := smoothstep(0.18,0.82,phase)
			turn_world(rig,"bip01 spine",Vector3.RIGHT,-0.38*rise)
			turn_world(rig,"bip01 spine1",Vector3.RIGHT,-0.39*rise)
			turn_world(rig,"bip01 neck",Vector3.RIGHT,-0.15*rise)
			turn_world(rig,"bip01 head",Vector3.RIGHT,0.14*rise)
			turn_world(rig,"bip01 tail",Vector3.RIGHT,0.26*rise)
		154:
			var curling := slot == 18
			turn_world(rig,"bip01 spine1",Vector3.RIGHT,(0.31 if curling else -0.26)*pulse)
			turn_world(rig,"bip01 spine2",Vector3.RIGHT,(0.28 if curling else -0.12)*pulse)
			turn_world(rig,"bip01 head",Vector3.RIGHT,(0.38 if curling else -0.13)*pulse)
			turn_world(rig,"bip01 r upperarm",Vector3.RIGHT,(-0.66 if curling else -0.47)*pulse)
			turn_world(rig,"bip01 l upperarm",Vector3.RIGHT,(-0.53 if curling else -0.33)*pulse)
			turn_world(rig,"bip01 r forearm",Vector3.RIGHT,-0.36*pulse)
			turn_world(rig,"bip01 l forearm",Vector3.RIGHT,-0.28*follow)
		80:
			pose_toad(rig,slot,pulse,follow)

func pose_toad(rig: Skeleton3D, slot: int, pulse: float, follow: float) -> void:
	match slot:
		6:
			turn_world(rig,"bip01 spine",Vector3.RIGHT,0.21*pulse-0.28*follow)
			turn_world(rig,"bip01 head",Vector3.RIGHT,-0.31*follow)
			for side: String in ["l","r"]:
				turn_world(rig,"bip01 "+side+" thigh",Vector3.RIGHT,-0.79*follow)
				turn_world(rig,"bip01 "+side+" calf",Vector3.RIGHT,0.59*follow)
				turn_world(rig,"bip01 "+side+" upperarm",Vector3.RIGHT,-0.56*follow)
		15:
			turn_world(rig,"bip01 spine1",Vector3.RIGHT,0.34*pulse)
			turn_world(rig,"bip01 neck",Vector3.RIGHT,0.24*pulse)
			turn_world(rig,"bip01 l upperarm",Vector3.RIGHT,0.38*pulse)
			turn_world(rig,"bip01 r calf",Vector3.RIGHT,-0.22*follow)
		16:
			turn_world(rig,"bip01 spine",Vector3.RIGHT,0.26*pulse)
			turn_world(rig,"bip01 neck",Vector3.RIGHT,0.29*pulse)
			turn_world(rig,"bip01 head",Vector3.UP,0.32*pulse)
			turn_world(rig,"bip01 r upperarm",Vector3.RIGHT,-0.61*pulse)
			turn_world(rig,"bip01 l upperarm",Vector3.RIGHT,-0.36*follow)
		18:
			turn_world(rig,"bip01 neck",Vector3.RIGHT,-0.12*pulse)
			turn_world(rig,"bip01 head",Vector3.RIGHT,0.19*pulse-0.10*follow)
			turn_world(rig,"bip01 ponytail1",Vector3.RIGHT,0.15*follow)
