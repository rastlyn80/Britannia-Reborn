# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Checked := preload("res://Presentation/SourceLaterCreatureProfile.gd")
const Body := 728
const Folder := "res://local-art/creatures/medusa"
const Classic := {0: "Walk", 1: "MedusaIdle", 2: "Death", 3: "Death2", 4: "MedusaShot",
	5: "MedusaHighShot", 10: "MedusaRecoil", 11: "MedusaSurvey", 12: "MedusaStare",
	15: "MedusaGuard", 22: "Walk", 23: "MedusaSurvey", 24: "Run", 25: "ReadyStance",
	26: "MedusaSurvey", 27: "MedusaHighShot", 28: "MedusaGuard"}


static func enable() -> bool:
	var folder := OS.get_environment("BR_MEDUSA_OUTPUT")
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
		"kind": "medusa", "family": "abyss", "status": "validated",
		"assets": assets, "asset_sha256": hashes, "profile": "monster",
		"presentation_script": "res://Presentation/MedusaVisual.gd",
		"bodies": [{"body": Body, "scale": [1.0, 1.0, 1.0], "native_profile": "monster"}],
		"classic_action_categories": classic, "loop_categories": ["MedusaIdle", "ReadyStance"],
		"enhanced_source_action_groups": {
			"0": {"0": ["MedusaShot", "MedusaHighShot"], "2": ["MedusaGuard"], "3": ["Death", "Death2"],
				"4": ["MedusaRecoil"], "5": ["MedusaSurvey", "MedusaGuard"], "8": ["MedusaGuard"],
				"11": ["MedusaStare"], "14": ["ReadyStance"], "15": ["MedusaSurvey"]},
			"1": {"5": ["MedusaSurvey", "MedusaGuard"]},
		},
	}
	return true
