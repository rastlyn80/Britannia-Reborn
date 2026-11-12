# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Body := 225
const Reference := 25
const Art := "res://local-art/creatures/timber-wolf-enhanced/"
const Renderer := "res://Presentation/SourceEnhancedTimberWolfVisual.gd"
const Motions := {
	"GreyWolfSnap": "TimberWolfSnap",
	"GreyWolfLowRecoil": "TimberWolfLowRecoil",
	"GreyWolfQuietStand": "TimberWolfQuietStand",
	"GreyWolfScentWatch": "TimberWolfScentWatch",
	"GreyWolfHowl": "TimberWolfHowl",
	"GreyWolfEarAlert": "TimberWolfEarAlert",
}


static func enable() -> bool:
	var base := Registry.entry(Body)
	if base.get("presentation_script") == Renderer:
		return true
	if base.get("kind") != "canines_wolf_timber" or not FileAccess.file_exists(Art + "manifest.json"):
		return false
	var record: Variant = JSON.parse_string(FileAccess.get_file_as_string(Art + "manifest.json"))
	if not record is Dictionary or record.get("schema") != 1:
		return false
	var grey := Registry.entry(Reference)
	var modes: Dictionary = grey.get("enhanced_source_action_groups", {}).duplicate(true)
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
	var assets := {}
	var pins := {}
	for style: String in ["original", "rounded", "modern"]:
		var candidate := Art + "225-" + style + ".scn"
		var entry: Dictionary = record.get("variants", {}).get(style, {})
		if not matches(Registry.asset_path(base, style), entry.get("base_sha256")):
			return false
		if not matches(Registry.asset_path(grey, style), entry.get("reference_sha256")):
			return false
		if not matches(candidate, entry.get("scene_sha256")) or not ResourceLoader.exists(candidate, "PackedScene"):
			return false
		assets[style] = candidate
		pins[style] = entry["scene_sha256"]
	var row := base.duplicate(true)
	row["assets"] = assets
	row["asset_sha256"] = pins
	row["presentation_script"] = Renderer
	row["enhanced_source_action_groups"] = modes
	row["archive_grounded_gestures"] = Motions.values()
	Registry.entries[Body] = row
	return true


static func matches(path: String, expected: Variant) -> bool:
	return expected is String and expected.length() == 64 and FileAccess.get_sha256(path) == expected
