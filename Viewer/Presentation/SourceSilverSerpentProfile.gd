# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Giant := preload("res://Presentation/SourceGiantSerpentProfile.gd")
const Body := 92
const Art := "res://local-art/creatures/silver-serpent-enhanced/"
const Renderer := "res://Presentation/SourceEnhancedSilverSerpentVisual.gd"


static func enable() -> bool:
	var base := Registry.entry(Body)
	if base.get("presentation_script") == Renderer:
		return true
	if (base.get("presentation_script") != "res://Presentation/SourceSilverSerpentVisual.gd"
			or Registry.entry(Giant.Body).get("presentation_script") != Giant.Renderer):
		return false
	if not FileAccess.file_exists(Art + "manifest.json"):
		return false
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(Art + "manifest.json"))
	if not manifest is Dictionary or manifest.get("schema") != 1:
		return false
	var assets := {}
	for style: String in ["original", "rounded", "modern"]:
		var source: String = str(manifest.get("base_sha256", {}).get(style, ""))
		var donor: String = str(manifest.get("donor_sha256", {}).get(style, ""))
		var path := Art + "silver-serpent-enhanced-" + style + ".scn"
		var expected: String = str(manifest.get("scene_sha256", {}).get(style, ""))
		if source.length() != 64 or FileAccess.get_sha256(Registry.asset_path(base, style)) != source:
			return false
		if donor.length() != 64 or FileAccess.get_sha256(Registry.asset_path(Registry.entry(Giant.Body), style)) != donor:
			return false
		if expected.length() != 64 or FileAccess.get_sha256(path) != expected or not ResourceLoader.exists(path, "PackedScene"):
			return false
		assets[style] = path
	var row := base.duplicate(true)
	row["assets"] = assets
	row["presentation_script"] = Renderer
	row["classic_action_categories"] = row.get("classic_action_categories", {}).merged({"3": "Death"})
	Registry.entries[Body] = row
	return true
