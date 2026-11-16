# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Checked := preload("res://Presentation/SourceLaterCreatureProfile.gd")
const Body := 721
const Folder := "res://local-art/creatures/maddening-horror"
const Classic := {0: "Walk", 1: "HorrorIdle", 2: "Death", 3: "Death2", 4: "HorrorReach",
	5: "HorrorSweep", 10: "HorrorRecoil", 11: "HorrorThreat", 12: "HorrorDrain", 15: "HorrorGuard",
	22: "Walk", 23: "HorrorTurn", 24: "Run", 25: "ReadyStance", 26: "HorrorTurn",
	27: "HorrorThreat", 28: "HorrorGuard"}


static func enable() -> bool:
	var folder := OS.get_environment("BR_MADDENING_HORROR_OUTPUT")
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
		"kind": "maddening_horror", "family": "abyss", "status": "validated",
		"assets": assets, "asset_sha256": hashes, "profile": "monster",
		"presentation_script": "res://Presentation/MaddeningHorrorVisual.gd",
		"bodies": [{"body": Body, "scale": [1.0, 1.0, 1.0], "native_profile": "monster"}],
		"classic_action_categories": classic, "loop_categories": ["HorrorIdle", "ReadyStance"],
		"enhanced_source_action_groups": {
			"0": {"0": ["HorrorReach", "HorrorSweep"], "2": ["HorrorGuard"], "3": ["Death", "Death2"],
				"4": ["HorrorRecoil"], "5": ["HorrorTurn", "HorrorThreat"], "8": ["HorrorGuard"],
				"11": ["HorrorDrain"], "14": ["ReadyStance"], "15": ["HorrorTurn"]},
			"1": {"5": ["HorrorTurn", "HorrorThreat"]},
		},
	}
	return true
