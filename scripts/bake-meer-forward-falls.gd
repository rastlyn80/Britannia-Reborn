extends "res://../scripts/bake-lattice-through-meer-actions.gd"

const MEER_BODIES := [770, 773]
const FALL_BONES := ["bip01", "bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head",
	"bip01 l thigh", "bip01 r thigh", "bip01 l calf", "bip01 r calf", "bip01 l foot", "bip01 r foot",
	"bip01 l upperarm", "bip01 r upperarm", "bip01 l forearm", "bip01 r forearm"]

func run() -> void:
	Registry.load_index()
	var path := "res://../work/creatures/lattice_through_meer_actions/prepared-client.json"
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
	for row: Dictionary in rows:
		var body := int(row.bodies[0].body)
		if body not in MEER_BODIES:
			continue
		Registry.entries[body] = row
		fitting_body = body
		bake_body(body, "meer-forward-fall-%d" % body, {3: "Death2"},
			["bake-meer-forward-falls.gd",
			 "bake-lattice-through-meer-actions.gd", "bake-frost-through-gargoyle-actions.gd",
			 "bake-swamp-widow-juka-actions.gd", "bake-zombie-actions.gd"])
	quit()

func fit_troll(player: AnimationPlayer, rig: Skeleton3D, skins: Array[Dictionary], _slot: int) -> Animation:
	return fit_grounded(player, rig, skins, 1.03 if fitting_body == 770 else 0.94,
		"bip01", FALL_BONES, pose_forward_fall, 0.009)

func pose_forward_fall(rig: Skeleton3D, phase: float) -> void:
	var kneel := smoothstep(0.08, 0.41, phase) * (1.0 - smoothstep(0.51, 0.89, phase))
	var pitch := smoothstep(0.21, 0.88, phase)
	var catch := smoothstep(0.38, 0.63, phase) * (1.0 - smoothstep(0.70, 1.0, phase))
	var mage := fitting_body == 770
	turn_world(rig, "bip01", Vector3.RIGHT, -1.50 * pitch)
	turn_world(rig, "bip01 spine", Vector3.RIGHT, -0.27 * kneel + 0.08 * pitch)
	turn_world(rig, "bip01 spine1", Vector3.FORWARD, (0.15 if mage else -0.12) * kneel)
	turn_world(rig, "bip01 spine2", Vector3.UP, (0.14 if mage else -0.15) * catch)
	turn_world(rig, "bip01 head", Vector3.RIGHT, 0.33 * catch - 0.13 * pitch)
	for side: String in ["l", "r"]:
		var near := side == "l"
		var sign := 1.0 if near else -1.0
		var thigh := (0.50 if mage else 0.75) if near else 0.34
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -thigh * kneel + (sign * 0.06 - (0.33 if mage else 0.20)) * pitch)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, 1.15 * thigh * kneel - (0.17 if mage else 0.11) * pitch)
		turn_world(rig, "bip01 %s foot" % side, Vector3.RIGHT, -0.20 * kneel)
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.RIGHT, 0.73 * catch - 0.10 * pitch)
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.FORWARD, sign * (0.26 * kneel + 0.31 * pitch))
		turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, 0.55 * catch + (0.04 if near else 0.03) * pitch)
