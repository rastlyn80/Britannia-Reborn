extends "res://../scripts/bake-swamp-widow-juka-actions.gd"

const NEXT := {
	20: {15: "LowBrace", 18: "AbdomenSignal"},
	792: {15: "ChaosDemonGuard", 18: "ChaosDemonScan"},
	771: {6: "MeerBackhand", 15: "MeerGuard", 18: "MeerLook"},
	265: {},
	281: {18: "ScoutShieldCheck"},
	755: {15: "GargoyleWingGuard", 18: "GargoyleGuardLook"},
	754: {15: "GargoyleWingGuard", 18: "GargoyleGuardLook"},
}
const UPPER := ["bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head",
	"bip01 l upperarm", "bip01 r upperarm", "bip01 l forearm", "bip01 r forearm"]
const STANCE := ["bip01 l thigh", "bip01 r thigh", "bip01 l calf", "bip01 r calf"]
const WINGS := ["gargoyle l mainwing1", "gargoyle r mainwing1", "gargoyle l mainwing2", "gargoyle r mainwing2"]

func _initialize() -> void:
	create_timer(70.0).timeout.connect(func(): quit(2))
	super._initialize()

func run() -> void:
	for body: int in NEXT:
		var row := Registry.entry(body).duplicate(true)
		if row.get("classic_gesture_batch") == "frost_through_gargoyle_actions":
			push_error("Refusing to overwrite an active creature action package")
			quit(1)
			return
		var assets := {}
		for treatment: String in row.asset_sha256:
			var path := Registry.asset_path(row, treatment)
			assert(row.asset_sha256[treatment] == FileAccess.get_sha256(path))
			assets[treatment] = path
		row.assets = assets
		Registry.entries[body] = row
		fitting_body = body
		bake_body(body, "frost-through-gargoyle-%d" % body, NEXT[body],
			["bake-frost-through-gargoyle-actions.gd",
			 "bake-swamp-widow-juka-actions.gd", "bake-zombie-actions.gd"])
	quit()

func fit_troll(player: AnimationPlayer, rig: Skeleton3D, skins: Array[Dictionary], slot: int) -> Animation:
	var length := 0.48 if slot == 15 else 0.72 if slot == 6 else 0.82
	if fitting_body == 20:
		var legs := ["bone01", "bone02"] + WIDOW_COXA + WIDOW_KNEES
		return fit_grounded(player, rig, skins, length, "bone01", legs, pose_widow.bind(slot))
	var joints := UPPER + STANCE
	if fitting_body in [754, 755]:
		joints += WINGS
	return fit_grounded(player, rig, skins, length, "bip01", joints, fit_form.bind(slot))

func fit_form(rig: Skeleton3D, phase: float, slot: int) -> void:
	var pulse := smoothstep(0.06, 0.42, phase) * (1.0 - smoothstep(0.56, 0.98, phase))
	var glance := pulse * sin(TAU * phase)
	if fitting_body in [754, 755]:
		if slot == 15:
			turn_world(rig, WINGS[0], Vector3.UP, -0.79 * pulse)
			turn_world(rig, WINGS[1], Vector3.UP, 0.79 * pulse)
			turn_world(rig, WINGS[2], Vector3.RIGHT, 0.25 * pulse)
			turn_world(rig, WINGS[3], Vector3.RIGHT, 0.25 * pulse)
			turn_world(rig, "bip01 head", Vector3.RIGHT, -0.24 * pulse)
		else:
			turn_world(rig, "bip01 head", Vector3.UP, 0.32 * glance)
			turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -0.54 * pulse)
			turn_world(rig, "bip01 l forearm", Vector3.RIGHT, 0.21 * pulse)
			turn_world(rig, WINGS[0], Vector3.UP, -0.08 * pulse)
			turn_world(rig, WINGS[1], Vector3.UP, 0.08 * pulse)
		return
	if fitting_body == 771 and slot == 6:
		pose_juka(rig, phase, slot)
		return
	if slot == 15:
		turn_world(rig, "bip01 spine1", Vector3.RIGHT, 0.19 * pulse)
		turn_world(rig, "bip01 spine2", Vector3.UP, 0.26 * pulse)
		turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -0.59 * pulse)
		turn_world(rig, "bip01 r upperarm", Vector3.FORWARD, 0.23 * pulse)
		turn_world(rig, "bip01 l forearm", Vector3.RIGHT, -0.20 * pulse)
		turn_world(rig, "bip01 l thigh", Vector3.RIGHT, -0.19 * pulse)
		turn_world(rig, "bip01 l calf", Vector3.RIGHT, 0.21 * pulse)
		return
	turn_world(rig, "bip01 head", Vector3.UP, 0.43 * glance)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, -0.13 * pulse)
	turn_world(rig, "bip01 spine2", Vector3.UP, 0.18 * pulse)
	if fitting_body == 792:
		turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, -0.42 * pulse)
		turn_world(rig, "bip01 r forearm", Vector3.RIGHT, -0.35 * pulse)
	elif fitting_body == 281:
		turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -0.44 * pulse)
		turn_world(rig, "bip01 l forearm", Vector3.UP, 0.22 * pulse)
		turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, -0.22 * pulse)
