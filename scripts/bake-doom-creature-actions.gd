# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-swamp-widow-juka-actions.gd"

const DOOM_CLIPS := {
	306: {15: "ImpalerShortRecoil", 18: "ImpalerClawCheck"},
	311: {15: "ShadowKnightShortGuard", 18: "ShadowKnightSwordCheck"},
	312: {15: "HorrorTentacleRecoil", 18: "HorrorTentacleSpread"},
	313: {15: "CreeperRear", 18: "CreeperCurl"},
	314: {15: "RavagerShortBrace", 18: "RavagerClubRaise"},
	315: {15: "FleshRendererFrontRecoil", 18: "FleshRendererShellRock"},
	316: {15: "WandererShortCurl", 18: "WandererBow"},
	318: {15: "DemonKnightShortGuard", 18: "DemonKnightTailCheck"},
	319: {15: "MoundShortTuck", 18: "MoundHeadRise"},
}

# Angles use the same world axes as the retained rigs. The motion pairs were
# fitted separately to the three-frame recoil and five-frame gesture silhouettes.
const CHANNELS := {
	306: {
		15: [["bip01 spine1", Vector3.RIGHT, -0.26], ["bip01 head", Vector3.RIGHT, -0.19],
			["bip01 r upperarm", Vector3.RIGHT, 0.36], ["bip01 l upperarm", Vector3.RIGHT, 0.33]],
		18: [["bip01 spine2", Vector3.RIGHT, -0.19], ["bip01 head", Vector3.UP, 0.29],
			["bip01 r upperarm", Vector3.RIGHT, -0.81], ["bip01 r forearm", Vector3.RIGHT, -0.63],
			["bip01 l upperarm", Vector3.FORWARD, -0.27]],
	},
	311: {
		15: [["bip01 spine1", Vector3.RIGHT, -0.15], ["bip01 spine2", Vector3.UP, 0.26],
			["bip01 r upperarm", Vector3.RIGHT, -0.25], ["bip01 r forearm", Vector3.RIGHT, -0.31],
			["bip01 l upperarm", Vector3.FORWARD, -0.37]],
		18: [["bip01 spine2", Vector3.RIGHT, 0.21], ["bip01 head", Vector3.UP, 0.20],
			["bip01 r upperarm", Vector3.RIGHT, 0.49], ["bip01 r forearm", Vector3.UP, -0.28],
			["bip01 r hand", Vector3.RIGHT, 0.28], ["bone_cloak_03", Vector3.RIGHT, -0.16]],
	},
	312: {
		15: [["head", Vector3.RIGHT, -0.26], ["rarm1", Vector3.FORWARD, -0.55],
			["larm1", Vector3.RIGHT, 0.58], ["larm2", Vector3.RIGHT, -0.52],
			["barm1", Vector3.RIGHT, 0.37]],
		18: [["head", Vector3.UP, 0.26], ["rarm1", Vector3.FORWARD, -0.62],
			["rarm2", Vector3.RIGHT, 0.38], ["larm1", Vector3.FORWARD, 0.83],
			["larm2", Vector3.RIGHT, -0.52], ["barm1", Vector3.RIGHT, -0.55]],
	},
	313: {
		15: [["uppbody1", Vector3.RIGHT, -0.28], ["uppbody2", Vector3.RIGHT, -0.13],
			["neck", Vector3.RIGHT, -0.22], ["lupparm1", Vector3.RIGHT, -0.37],
			["rupparm1", Vector3.RIGHT, -0.36]],
		18: [["uppbody1", Vector3.RIGHT, 0.59], ["uppbody2", Vector3.RIGHT, 0.41],
			["neck", Vector3.RIGHT, -0.38], ["head", Vector3.UP, 0.36],
			["lowbody2", Vector3.RIGHT, -0.16], ["tail1", Vector3.RIGHT, 0.46]],
	},
	314: {
		15: [["bip01 spine2", Vector3.RIGHT, -0.23], ["bip01 neck1", Vector3.RIGHT, -0.23],
			["bip01 r upperarm", Vector3.RIGHT, -0.43], ["r2arm1", Vector3.FORWARD, 0.23],
			["l2arm1", Vector3.FORWARD, -0.23]],
		18: [["bip01 spine1", Vector3.RIGHT, -0.19], ["bip01 head", Vector3.RIGHT, 0.26],
			["bip01 r upperarm", Vector3.RIGHT, -1.10], ["bip01 r forearm", Vector3.RIGHT, -0.58],
			["bip01 l upperarm", Vector3.RIGHT, -0.35], ["r3arm1", Vector3.FORWARD, 0.34],
			["l3arm1", Vector3.FORWARD, -0.30]],
	},
	315: {
		15: [["bip01 bone spine1", Vector3.RIGHT, -0.23], ["bip01 bone spine2", Vector3.RIGHT, -0.19],
			["bip01 bone lf1", Vector3.RIGHT, -0.61], ["bip01 bone lf2", Vector3.RIGHT, -0.62],
			["bip01 bone fr1", Vector3.RIGHT, -0.53], ["bip01 bone fr2", Vector3.RIGHT, -0.44],
			["bip01 bone tenical 1a", Vector3.RIGHT, -0.25]],
		18: [["bip01 bone spine1", Vector3.FORWARD, 0.13], ["bip01 bon spine3", Vector3.RIGHT, -0.14],
			["bip01 bone spine4", Vector3.RIGHT, -0.21], ["bip01 bone rb1", Vector3.RIGHT, -0.37],
			["bip01 bone rb2", Vector3.RIGHT, -0.38]],
	},
	316: {
		15: [["spine2", Vector3.RIGHT, 0.18], ["neck1", Vector3.RIGHT, 0.35],
			["neck2", Vector3.RIGHT, 0.29], ["bip01 head", Vector3.UP, 0.24]],
		18: [["spine2", Vector3.RIGHT, 0.23], ["neck1", Vector3.RIGHT, 0.59],
			["neck2", Vector3.RIGHT, 0.43], ["bip01 head", Vector3.RIGHT, -0.16],
			["ant1a", Vector3.FORWARD, 0.27], ["ant2a", Vector3.FORWARD, -0.29]],
	},
	318: {
		15: [["bip01 spine2", Vector3.RIGHT, -0.21], ["bip01 head", Vector3.RIGHT, -0.17],
			["bip01 r upperarm", Vector3.RIGHT, -0.62], ["bip01 r forearm", Vector3.RIGHT, -0.35],
			["bip01 tail1", Vector3.RIGHT, 0.18]],
		18: [["bip01 spine2", Vector3.UP, 0.23], ["bip01 head", Vector3.RIGHT, -0.24],
			["bip01 l upperarm", Vector3.FORWARD, -0.29], ["bip01 tail1", Vector3.RIGHT, -0.31],
			["bip01 tail2", Vector3.UP, -0.42], ["bip01 tail3", Vector3.UP, -0.30]],
	},
	319: {
		15: [["neck01", Vector3.RIGHT, 0.11], ["neck02", Vector3.RIGHT, 0.12],
			["head", Vector3.RIGHT, -0.10]],
		18: [["neck01", Vector3.RIGHT, -0.35], ["neck02", Vector3.RIGHT, -0.28],
			["neck03", Vector3.RIGHT, -0.18], ["head", Vector3.RIGHT, 0.23]],
	},
}

func run() -> void:
	Registry.load_index()
	for body: int in DOOM_CLIPS:
		var row := Registry.entry(body).duplicate(true)
		if row.get("classic_gesture_batch") == "doom_creature_actions":
			row = preload("res://Presentation/SealedCreatureActionBase.gd").retained(row, body)
		var assets := {}
		for treatment: String in ["original", "rounded", "modern"]:
			var path := Registry.asset_path(row, treatment)
			var expected: String = row.asset_sha256[treatment] if row.has("asset_sha256") else row.saved_scenes[treatment].scene_sha256
			assert(FileAccess.get_sha256(path) == expected, str([body, treatment, path]))
			assets[treatment] = path
		row.assets = assets
		Registry.entries[body] = row
		fitting_body = body
		bake_body(body, "doom-creature-%d" % body, DOOM_CLIPS[body],
			["bake-doom-creature-actions.gd", "doom-creature-action-pins.json",
				"bake-swamp-widow-juka-actions.gd", "bake-zombie-actions.gd"])
	quit()

func fit_troll(player: AnimationPlayer, rig: Skeleton3D, skins: Array[Dictionary], slot: int) -> Animation:
	var channels: Array = CHANNELS[fitting_body][slot]
	var joints := channels.map(func(channel: Array) -> String: return channel[0])
	return fit_grounded(player, rig, skins, 0.47 if slot == 15 else 0.83, "bip01",
		joints, pose_doom.bind(channels, slot), 0.009)

func pose_doom(rig: Skeleton3D, phase: float, channels: Array, slot: int) -> void:
	var effort := smoothstep(0.05, 0.43, phase) * (1.0 - smoothstep(0.57, 0.98, phase))
	if slot == 18:
		effort *= 0.86 + 0.14 * sin(TAU * phase)
	for channel: Array in channels:
		turn_world(rig, channel[0], channel[1], channel[2] * effort)
