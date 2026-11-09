extends "res://../scripts/bake-raptor-uop-actions.gd"

const BODY := 130
const FIRE_CLIPS := {3: "Death2", 5: "FireGargoyleLunge", 15: "FireGargoyleGuard",
	22: "FireGargoylePeaceWalk", 23: "FireGargoyleRise", 25: "ReadyStance", 26: "FireGargoyleRest",
	27: "FireGargoyleFlare", 28: "FireGargoyleRecoil"}
const FIT := ["bip01", "bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head",
	"bip01 l upperarm", "bip01 r upperarm", "bip01 l forearm", "bip01 r forearm",
	"bip01 l thigh", "bip01 r thigh", "bip01 l calf", "bip01 r calf",
	"gargoyle l mainwing1", "gargoyle r mainwing1"]

func _initialize() -> void:
	create_timer(70.0).timeout.connect(func(): quit(2))
	super._initialize()

func run() -> void:
	var row := Registry.entry(BODY).duplicate(true)
	if row.get("classic_gesture_batch") == "frost_through_gargoyle_actions":
		push_error("Refusing to overwrite an active creature action package")
		quit(1)
		return
	for treatment: String in row.assets:
		assert(FileAccess.get_sha256(row.assets[treatment]) == row.asset_sha256[treatment])
	Registry.entries[BODY] = row
	bake_body(BODY, "fire-gargoyle-uop", FIRE_CLIPS,
		["bake-fire-gargoyle-uop-actions.gd",
		 "bake-raptor-uop-actions.gd", "bake-swamp-widow-juka-actions.gd", "bake-zombie-actions.gd"])
	quit()

func fit_troll(player: AnimationPlayer, rig: Skeleton3D, skins: Array[Dictionary], slot: int) -> Animation:
	if slot == 22:
		return reframe_walk(player, rig, ["bip01 spine2", "bip01 head", "bip01 l upperarm",
			"bip01 r upperarm", "gargoyle l mainwing1", "gargoyle r mainwing1"], peaceful_body)
	var length := {3: 0.95, 5: 0.72, 15: 0.64, 23: 1.06, 25: 1.10, 26: 0.94, 27: 1.03, 28: 0.58}
	return fit_grounded(player, rig, skins, length[slot], "bip01", FIT, pose_form.bind(slot))

func peaceful_body(rig: Skeleton3D, phase: float) -> void:
	var sway := sin(TAU * phase)
	turn_world(rig, "bip01 spine2", Vector3.RIGHT, -0.05)
	turn_world(rig, "bip01 head", Vector3.UP, 0.055 * sway)
	turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -0.12 - 0.06 * sway)
	turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, -0.12 + 0.06 * sway)
	turn_world(rig, "gargoyle l mainwing1", Vector3.UP, 0.10)
	turn_world(rig, "gargoyle r mainwing1", Vector3.UP, -0.10)

func pose_form(rig: Skeleton3D, phase: float, slot: int) -> void:
	var pulse := smoothstep(0.05, 0.41, phase) * (1.0 - smoothstep(0.60, 0.98, phase))
	if slot == 3:
		var fall := smoothstep(0.18, 0.85, phase)
		var stagger := smoothstep(0.02, 0.25, phase) * (1.0 - smoothstep(0.31, 0.62, phase))
		turn_world(rig, "bip01", Vector3.RIGHT, -1.43 * fall)
		turn_world(rig, "bip01 spine2", Vector3.UP, 0.20 * fall)
		turn_world(rig, "bip01 neck", Vector3.RIGHT, 0.19 * fall)
		turn_world(rig, "bip01 r thigh", Vector3.RIGHT, 0.47 * stagger + 0.21 * fall)
		turn_world(rig, "bip01 r calf", Vector3.RIGHT, -0.53 * stagger)
		turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -0.69 * stagger + 0.22 * fall)
		turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, -0.29 * fall)
		turn_world(rig, "gargoyle l mainwing1", Vector3.UP, -0.35 * fall)
		turn_world(rig, "gargoyle r mainwing1", Vector3.UP, 0.35 * fall)
		return
	if slot == 5:
		pose_juka(rig, phase, 6)
		return
	if slot == 23:
		var crouch := 1.0 - smoothstep(0.02, 0.65, phase)
		turn_world(rig, "bip01 spine1", Vector3.RIGHT, 0.69 * crouch)
		turn_world(rig, "bip01 neck", Vector3.RIGHT, -0.26 * crouch)
		for side: String in ["l", "r"]:
			turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -0.79 * crouch)
			turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, 0.87 * crouch)
			turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, -0.62 * crouch)
		return
	if slot in [25, 26]:
		var breath := sin(TAU * phase) * pulse
		var settle := 0.14 if slot == 26 else 0.035
		turn_world(rig, "bip01 head", Vector3.UP, 0.08 * breath)
		turn_world(rig, "bip01 spine2", Vector3.RIGHT, 0.06 * pulse)
		turn_world(rig, "bip01 l forearm", Vector3.RIGHT, -settle * pulse)
		turn_world(rig, "bip01 r forearm", Vector3.RIGHT, -settle * pulse)
		return
	var extension := 0.48 if slot == 27 else -0.27 if slot == 15 else 0.18
	turn_world(rig, "bip01 spine2", Vector3.RIGHT, 0.25 * pulse)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -0.21 * pulse)
	turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -0.55 * pulse)
	turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, -0.33 * pulse)
	turn_world(rig, "bip01 l forearm", Vector3.RIGHT, extension * pulse)
	turn_world(rig, "bip01 r forearm", Vector3.RIGHT, extension * pulse)
	turn_world(rig, "gargoyle l mainwing1", Vector3.UP, -extension * pulse)
	turn_world(rig, "gargoyle r mainwing1", Vector3.UP, extension * pulse)
