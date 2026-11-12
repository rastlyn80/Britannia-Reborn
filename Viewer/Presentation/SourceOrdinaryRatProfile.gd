# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Body := 238
const Donor := 215
const Art := "res://local-art/creatures/ordinary-rat-enhanced/"
const Renderer := "res://Presentation/SourceEnhancedOrdinaryRatVisual.gd"
const Motions := {
	"GiantRatForwardBite": "RatForwardBite",
	"GiantRatNoseRecoil": "RatNoseRecoil",
	"GiantRatTailUnfurl": "RatTailUnfurl",
	"GiantRatForage": "RatForage",
	"GiantRatScentCheck": "RatScentCheck",
	"GiantRatTailSweep": "RatTailSweep",
	"GiantRatNoseAlert": "RatNoseAlert",
}


static func enable() -> bool:
	var base := Registry.entry(Body)
	if base.get("presentation_script") == Renderer:
		return true
	if base.get("kind") != "rat_ordinary" or not FileAccess.file_exists(Art + "manifest.json"):
		return false
	var record: Variant = JSON.parse_string(FileAccess.get_file_as_string(Art + "manifest.json"))
	if not record is Dictionary or record.get("schema") != 1:
		return false
	var donor := Registry.entry(Donor)
	var scene := Art + "rat-enhanced.scn"
	if not matches(Registry.asset_path(base), record.get("source_sha256")) \
			or not matches(Registry.asset_path(donor), record.get("donor_sha256")) \
			or not matches(scene, record.get("scene_sha256")) or not ResourceLoader.exists(scene, "PackedScene"):
		return false
	var modes: Dictionary = donor.get("enhanced_source_action_groups", {}).duplicate(true)
	var used := {}
	for mode: Dictionary in modes.values():
		for group: Array in mode.values():
			for index in group.size():
				var label: String = group[index]
				if not Motions.has(label):
					return false
				group[index] = Motions[label]
				used[label] = true
	if used.size() != Motions.size():
		return false
	var row := base.duplicate(true)
	row["assets"]["modern"] = scene
	row["asset_sha256"] = {"modern": record["scene_sha256"]}
	row["presentation_script"] = Renderer
	row["enhanced_source_action_groups"] = modes
	row["archive_grounded_gestures"] = Motions.values()
	Registry.entries[Body] = row
	return true


static func matches(path: String, expected: Variant) -> bool:
	return expected is String and expected.length() == 64 and FileAccess.get_sha256(path) == expected
