# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Checked := preload("res://Presentation/SourceLaterCreatureProfile.gd")
const Body := 741
const Folder := "res://local-art/creatures/slasher-of-veils"
const Classic := {0: "Walk", 1: "SlasherIdle", 2: "Death", 3: "Death2", 4: "SlasherRake",
	5: "SlasherDoubleClaw", 10: "SlasherRecoil", 11: "SlasherSurvey", 12: "SlasherFear",
	15: "SlasherGuard", 22: "Walk", 23: "SlasherVeil", 24: "Run", 25: "ReadyStance",
	26: "SlasherSurvey", 27: "SlasherFire", 28: "SlasherGuard"}


static func enable() -> bool:
	var folder := OS.get_environment("BR_SLASHER_OUTPUT")
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
		var path := folder.path_join("%d-%s-%s.scn" % [Body, style, digest])
		if not ResourceLoader.exists(path, "PackedScene") or FileAccess.get_sha256(path) != digest:
			return false
		assets[style] = path
	var classic := {}
	for group: int in Classic:
		classic[str(group)] = Classic[group]
	Registry.load_index()
	Registry.entries[Body] = {
		"kind": "slasher_of_veils", "family": "abyss", "status": "validated",
		"assets": assets, "asset_sha256": hashes, "profile": "monster",
		"presentation_script": "res://Presentation/SlasherVisual.gd",
		"bodies": [{"body": Body, "scale": [1.0, 1.0, 1.0], "native_profile": "monster"}],
		"classic_action_categories": classic, "loop_categories": ["SlasherIdle", "ReadyStance"],
		"enhanced_source_action_groups": {
			"0": {"0": ["SlasherRake", "SlasherDoubleClaw"], "2": ["SlasherGuard"], "3": ["Death", "Death2"],
				"4": ["SlasherRecoil"], "5": ["SlasherSurvey", "SlasherFire"], "8": ["SlasherGuard"],
				"11": ["SlasherFear"], "14": ["ReadyStance"], "15": ["SlasherVeil"]},
			"1": {"5": ["SlasherSurvey", "SlasherFire"]},
		},
	}
	return true
