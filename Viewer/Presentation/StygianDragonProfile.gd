# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Checked := preload("res://Presentation/SourceLaterCreatureProfile.gd")
const Body := 826
const Folder := "res://local-art/creatures/stygian-dragon"
const Classic := {0: "Walk", 1: "StygianRest", 2: "Death", 3: "Death2", 4: "StygianRake",
	5: "StygianLunge", 10: "StygianRecoil", 11: "Fly", 12: "StygianWingGuard", 15: "StygianWingGuard",
	19: "Fly", 22: "Walk", 23: "Land", 24: "Run", 25: "StygianRest", 26: "StygianRest",
	27: "StygianBreath", 28: "TakeOff", 29: "StygianRest", 30: "StygianTailCheck"}


static func enable() -> bool:
	var folder := OS.get_environment("BR_STYGIAN_DRAGON_OUTPUT")
	if folder.is_empty():
		folder = Folder
	var profile := folder.path_join("profile.json")
	if not FileAccess.file_exists(profile):
		return false
	var row: Variant = JSON.parse_string(FileAccess.get_file_as_string(profile))
	if not row is Dictionary or row.get("schema") != 1 or row.get("body") != Body:
		return false
	var hashes: Variant = row.get("asset_sha256")
	if not hashes is Dictionary:
		return false
	var assets := {}
	for style: String in Checked.Styles:
		var digest := str(hashes.get(style, ""))
		if not Checked.is_digest(digest):
			return false
		var scene := folder.path_join("%d-%s-%s.scn" % [Body, style, digest])
		if not ResourceLoader.exists(scene, "PackedScene") or FileAccess.get_sha256(scene) != digest:
			return false
		assets[style] = scene
	var classic := {}
	for group: int in Classic:
		classic[str(group)] = Classic[group]
	Registry.load_index()
	Registry.entries[Body] = {
		"kind": "stygian_dragon", "family": "dragons", "status": "validated",
		"assets": assets, "asset_sha256": hashes, "profile": "monster",
		"presentation_script": "res://Presentation/StygianDragonVisual.gd",
		"bodies": [{"body": Body, "scale": [1.0, 1.0, 1.0], "native_profile": "monster"}],
		"classic_action_categories": classic,
		"loop_categories": ["StygianRest", "ReadyStance", "Fly"],
		"enhanced_source_action_groups": {
			"0": {"0": ["StygianRake", "StygianLunge"], "2": ["StygianWingGuard"],
				"3": ["Death", "Death2"], "4": ["StygianRecoil"], "5": ["StygianRest", "StygianTailCheck"],
				"8": ["TakeOff"], "11": ["StygianBreath"], "14": ["StygianRest"], "15": ["Land"]},
			"1": {"5": ["StygianRest", "StygianTailCheck"]},
		},
	}
	return true
