# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Body := 150
const Art := "res://local-art/creatures/sea-serpent-enhanced/"
const Renderer := "res://Presentation/SourceEnhancedSeaSerpentVisual.gd"


static func enable() -> bool:
	var base := Registry.entry(Body)
	if base.get("presentation_script") == Renderer:
		return true
	if base.get("kind") != "sea_serpents_sea_serpent_classic" or base.get("movement_mode") != "native_waterline":
		return false
	if not FileAccess.file_exists(Art + "manifest.json"):
		return false
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(Art + "manifest.json"))
	if not manifest is Dictionary or manifest.get("schema") != 1:
		return false
	var assets := {}
	for style: String in ["original", "rounded", "modern"]:
		var base_hash: String = str(manifest.get("base_sha256", {}).get(style, ""))
		var path := Art + "sea-serpent-enhanced-" + style + ".scn"
		var expected: String = str(manifest.get("scene_sha256", {}).get(style, ""))
		if base_hash.length() != 64 or FileAccess.get_sha256(Registry.asset_path(base, style)) != base_hash:
			return false
		if expected.length() != 64 or FileAccess.get_sha256(path) != expected or not ResourceLoader.exists(path, "PackedScene"):
			return false
		assets[style] = path
	var row := base.duplicate(true)
	row["assets"] = assets
	row["presentation_script"] = Renderer
	Registry.entries[Body] = row
	return true
