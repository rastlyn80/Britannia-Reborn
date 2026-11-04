extends "res://../scripts/bake-zombie-actions.gd"

func run() -> void:
	bake_body(8, "corpser", {2: "Death2", 4: "InwardHook", 6: "DoubleLash", 15: "Death", 18: "TendrilCurl"},
		["bake-corpser-actions.gd", "bake-zombie-actions.gd"])
	quit()

func add_retained_actions(player: AnimationPlayer, rig: Skeleton3D, row: Dictionary, treatment: String) -> void:
	player.get_animation_library("").rename_animation("Death", "RecoveredDeath")
	if treatment == "modern":
		assert(player.has_animation("Emerge"))
		return
	var donor := (load(Registry.asset_path(row, "modern")) as PackedScene).instantiate()
	var donor_player := donor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var donor_rig := donor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	assert(rig.get_bone_count() == donor_rig.get_bone_count())
	assert(player.get_node(player.root_node).get_path_to(rig) == donor_player.get_node(donor_player.root_node).get_path_to(donor_rig))
	for bone in rig.get_bone_count():
		assert(rig.get_bone_name(bone) == donor_rig.get_bone_name(bone))
		assert(rig.get_bone_parent(bone) == donor_rig.get_bone_parent(bone))
		assert(rig.get_bone_rest(bone).is_equal_approx(donor_rig.get_bone_rest(bone)))
	assert(player.get_animation_library("").add_animation("Emerge", donor_player.get_animation("Emerge").duplicate(true)) == OK)
	donor.free()

func pose_troll(rig: Skeleton3D, slot: int, phase: float) -> void:
	var rise := smoothstep(0.00, 0.25, phase) * (1.0 - smoothstep(0.32, 0.68, phase))
	var release := smoothstep(0.24, 0.59, phase) * (1.0 - smoothstep(0.66, 1.0, phase))
	if slot in [2, 15]:
		# The two tendrils fold from their own bases. Keep the rooted flower
		# from tipping onto a tendril and lifting the entire body off the ground.
		var first := smoothstep(0.11, 0.89, phase)
		var second := smoothstep(0.23, 0.98, phase)
		var splay := slot == 2
		lower_chain(rig, "1", first if splay else second, -0.43 if splay else 0.25, splay)
		lower_chain(rig, "2", second if splay else first, 0.45 if splay else -0.22, splay)
		return
	if slot == 4:
		bend_chain(rig, "1", Vector3.UP, -0.45 * rise + 0.67 * release)
		bend_chain(rig, "1", Vector3.RIGHT, -0.34 * rise + 0.66 * release)
		bend_chain(rig, "2", Vector3.UP, -0.24 * release)
		return
	if slot == 6:
		bend_chain(rig, "1", Vector3.RIGHT, -0.62 * rise + 0.75 * release)
		bend_chain(rig, "2", Vector3.RIGHT, -0.24 * rise + 0.64 * release)
		bend_chain(rig, "2", Vector3.UP, -0.40 * release)
		return
	bend_chain(rig, "1", Vector3.UP, 0.21 * release)
	bend_chain(rig, "2", Vector3.RIGHT, -0.29 * rise + 0.32 * release)
	bend_chain(rig, "2", Vector3.UP, 0.31 * release)

func bend_chain(rig: Skeleton3D, chain: String, axis: Vector3, amount: float) -> void:
	var joint := "bip01 ponytail" + chain
	turn_world(rig, joint, axis, amount * 0.72)
	turn_world(rig, joint + "1", axis, amount * 0.41)
	turn_world(rig, joint + "2", axis, amount * 0.26)
	turn_world(rig, joint + "3", axis, amount * -0.19)

func lower_chain(rig: Skeleton3D, chain: String, amount: float, splay: float, spread: bool) -> void:
	var label := "bip01 ponytail" + chain
	var first := rig.find_bone(label)
	var direction := joint_world(rig, label + "1") - joint_world(rig, label)
	direction.y = 0.0
	direction = direction.normalized()
	for segment in 3:
		var upper := first + segment
		var lower := upper + 1
		assert(rig.get_bone_parent(lower) == upper)
		var start := rig.get_bone_global_pose(upper).origin
		var end := rig.get_bone_global_pose(lower).origin
		var turn: float = [0.0, 0.27, 0.54][segment] if spread else [0.0, 0.56, 0.97][segment]
		var height: float = [0.12, -0.04, 0.10][segment] if spread else [0.22, 0.03, 0.04][segment]
		var aim := direction.rotated(Vector3.UP, splay + signf(splay) * turn) + Vector3.UP * height
		var target := start + (rig.global_basis.inverse() * aim.normalized()) * start.distance_to(end)
		Arms.aim(rig, upper, lower, end.lerp(target, amount))
