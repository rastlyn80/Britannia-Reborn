extends "res://../scripts/bake-zombie-actions.gd"

const CAPTAIN := {3:"Death2", 15:"CaptainHighGuard", 16:"CaptainLowGuard",
	17:"CaptainAxeSignal", 18:"CaptainAxeCheck"}
const ART := "res://local-art/creatures/"
var group := 0

func run() -> void:
	var base := Registry.entry(7).duplicate(true)
	base.assets = {}
	for treatment: String in ["original", "rounded", "modern"]:
		base.assets[treatment] = ART + "orc-captain-7-axe-%s.scn" % treatment
	Registry.entries[7] = base
	bake_body(7, "orc-captain-motion", CAPTAIN, [])
	quit()

func write_receipt(_name: String, _body: int, _scenes: Dictionary, _inputs: Array[String]) -> void:
	pass

func fit_troll(player: AnimationPlayer, rig: Skeleton3D, skins: Array[Dictionary], slot: int) -> Animation:
	group = slot
	return super.fit_troll(player, rig, skins, 2 if slot == 3 else (18 if slot == 17 else slot))

func pose_troll(rig: Skeleton3D, _slot: int, phase: float) -> void:
	var pulse := smoothstep(0.05, 0.43, phase) * (1.0 - smoothstep(0.66, 0.99, phase))
	if group == 3:
		var fall := smoothstep(0.12, 0.92, phase)
		turn_world(rig, "bip01", Vector3.RIGHT, 1.45 * fall)
		turn_world(rig, "bip01 spine2", Vector3.FORWARD, -0.21 * fall)
		turn_world(rig, "bip01 head", Vector3.RIGHT, -0.16 * fall)
		turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -0.75 * fall)
		turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, -0.45 * fall)
		turn_world(rig, "bip01 l calf", Vector3.RIGHT, 0.36 * fall)
		turn_world(rig, "bip01 r calf", Vector3.RIGHT, 0.20 * fall)
		return
	var lift := {15: -0.84, 16: -0.30, 17: -1.42, 18: -0.58}[group] as float
	var twist := {15: -0.24, 16: 0.42, 17: -0.08, 18: 0.27}[group] as float
	turn_world(rig, "bip01 spine2", Vector3.UP, twist * pulse)
	turn_world(rig, "bip01 head", Vector3.UP, -0.29 * twist * pulse)
	turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, lift * pulse)
	turn_world(rig, "bip01 r forearm", Vector3.RIGHT, (-0.52 if group in [15, 17] else 0.16) * pulse)
	turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -0.16 * pulse)

func point_weapon(rig: Skeleton3D, _slot: int, phase: float) -> void:
	var axe := rig.find_bone("orc captain axe")
	var hand := rig.find_bone("bip01 r hand")
	var pulse := smoothstep(0.05, 0.43, phase) * (1.0 - smoothstep(0.66, 0.99, phase))
	if group == 3:
		pulse = smoothstep(0.32, 0.92, phase)
	var desired: Vector3 = {
		3: Vector3(-0.51, 0.20, 0.86), 15: Vector3(-0.35, 0.88, -0.25),
		16: Vector3(-0.72, -0.16, 0.60), 17: Vector3(-0.13, 0.98, 0.18), 18: Vector3(-0.73, 0.45, 0.48),
	}[group]
	var goal := (rig.global_basis.inverse() * desired).normalized()
	var current := rig.get_bone_global_pose(axe).basis.y.normalized()
	var pose := rig.get_bone_global_pose(hand)
	pose.basis = Basis(Quaternion.IDENTITY.slerp(Quaternion(current, goal), pulse)) * pose.basis
	rig.set_bone_global_pose(hand, pose)
	rig.force_update_all_bone_transforms()
