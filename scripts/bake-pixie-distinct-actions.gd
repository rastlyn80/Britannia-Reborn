extends "res://../scripts/bake-zombie-actions.gd"

func run() -> void:
	var base := Registry.entry(128)
	var row := base.duplicate(true)
	row.assets = {}
	for treatment: String in ["original", "rounded", "modern"]:
		row.assets[treatment] = Registry.asset_path(base,treatment)
	Registry.entries[128] = row
	bake_body(128, "pixie-distinct", {15:"PixieFlinch",18:"PixieSpiral"}, ["bake-pixie-distinct-actions.gd", "bake-zombie-actions.gd"])
	quit()

func fit_troll(player: AnimationPlayer, rig: Skeleton3D, skins: Array[Dictionary], slot: int) -> Animation:
	var clip := super.fit_troll(player, rig, skins, slot)
	if slot != 18:
		return clip
	var path := player.get_node(player.root_node).get_path_to(rig)
	var track := clip.find_track(NodePath("%s:bip01" % path),Animation.TYPE_POSITION_3D)
	var root_joint := rig.find_bone("bip01")
	var parent := rig.get_bone_parent(root_joint)
	var axis := rig.get_bone_global_pose(parent).basis.inverse() * rig.global_basis.inverse() * Vector3.UP
	for key in clip.track_get_key_count(track):
		var time := clip.track_get_key_time(track,key)
		var phase := time / clip.length
		var lift := sin(PI * phase)
		var original: Vector3 = clip.track_get_key_value(track,key)
		clip.track_set_key_value(track,key,original + axis * lift * lift * 0.28)
	return clip

func pose_troll(rig: Skeleton3D, slot: int, phase: float) -> void:
	var pulse := smoothstep(0.06,0.34,phase) * (1.0-smoothstep(0.5,0.97,phase))
	if slot == 15:
		turn_world(rig,"bip01 spine1",Vector3.RIGHT,-0.22*pulse)
		turn_world(rig,"bip01 r upperarm",Vector3.RIGHT,-0.72*pulse)
		turn_world(rig,"bip01 l upperarm",Vector3.RIGHT,-0.39*pulse)
		turn_world(rig,"bip01 r calf",Vector3.RIGHT,-0.27*pulse)
	else:
		var spin := smoothstep(0.08,0.90,phase)
		turn_world(rig,"bip01",Vector3.UP,TAU*spin)
		turn_world(rig,"bip01 spine1",Vector3.RIGHT,-0.25*pulse)
		turn_world(rig,"bip01 r upperarm",Vector3.RIGHT,-1.38*pulse)
		turn_world(rig,"bip01 l upperarm",Vector3.RIGHT,-0.93*pulse)
	for side: String in ["l","r"]:
		var sign := -1.0 if side == "l" else 1.0
		var wing := (0.46*pulse if slot == 15 else 0.48*sin(TAU*phase)*pulse) * sign
		turn_world(rig,"pixie "+side+" wing1",Vector3.UP,wing)
		turn_world(rig,"pixie "+side+" wing2",Vector3.BACK,0.19*pulse*sign)
