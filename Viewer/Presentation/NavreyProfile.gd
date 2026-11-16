# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const CheckedScenes := preload("res://Presentation/SourceLaterCreatureProfile.gd")
const Body := 735
const Folder := "res://local-art/creatures/navrey"
const Classic := {0: "Walk", 1: "Idle", 2: "Death", 3: "Death2", 4: "NavreySnap",
	5: "NavreyRearingStrike", 6: "NavreySnap", 10: "Hit", 11: "NavreyWatch", 12: "NavreySnap",
	15: "NavreyBrace", 17: "Fidget", 18: "NavreyWatch", 19: "NavreySilkLift",
	22: "NavreyPeaceWalk", 23: "NavreySilkDescent", 24: "Run", 25: "ReadyStance",
	26: "NavreyWatch", 27: "NavreyAbdomenRears", 28: "NavreyAlert"}


static func enable(folder := "") -> bool:
	if folder.is_empty():
		folder = OS.get_environment("BR_NAVREY_OUTPUT")
	if folder.is_empty():
		folder = Folder
	var path := folder.path_join("profile.json")
	if not FileAccess.file_exists(path):
		return false
	var row: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not row is Dictionary or row.get("schema") != 1 or row.get("body") != Body:
		return false
	var hashes: Variant = row.get("asset_sha256")
	if not hashes is Dictionary:
		return false
	var assets := {}
	for style: String in ["original", "rounded", "modern"]:
		var digest := str(hashes.get(style, ""))
		if not CheckedScenes.is_digest(digest):
			return false
		var scene := folder.path_join("%d-%s-%s.scn" % [Body, style, digest])
		if not ResourceLoader.exists(scene, "PackedScene") or FileAccess.get_sha256(scene) != digest:
			return false
		assets[style] = scene
	var classic := {}
	for group: int in Classic:
		classic[str(group)] = Classic[group]
	Registry.load_index()
	Registry.entries[Body] = {"kind": "navrey_night_eyes", "family": "arachnids", "status": "validated",
		"assets": assets, "asset_sha256": hashes, "profile": "monster",
		"presentation_script": "res://Presentation/NavreyVisual.gd",
		"bodies": [{"body": Body, "scale": [1.0, 1.0, 1.0], "native_profile": "monster"}],
		"classic_action_categories": classic, "loop_categories": ["NavreyPeaceWalk", "ReadyStance"],
		"enhanced_source_action_groups": {
			"0": {"0": ["NavreySnap", "NavreyRearingStrike", "NavreySnap", "NavreySnap", "NavreySnap", "NavreySnap"],
				"2": ["NavreyBrace"], "3": ["Death", "Death2"], "4": ["Hit"],
				"5": ["NavreyWatch", "NavreyAbdomenRears"], "8": ["NavreyAlert"], "11": ["NavreySnap"],
				"14": ["ReadyStance"], "15": ["NavreySilkDescent"]},
			"1": {"5": ["NavreyWatch"]}
		}}
	return true
