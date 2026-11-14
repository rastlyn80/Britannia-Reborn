# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Manifest := "res://local-art/creatures/later-prepared/profile.json"
const SupportedBodies := {714: "iron_beetle", 715: "ruddy_boura", 716: "chicken_lizard", 717: "clockwork_scorpion", 718: "fairy_dragon", 720: "lava_elemental",
	722: "undead_guardian", 723: "goblin",
	726: "kepetch", 732: "rotworm", 733: "skree", 736: "wolf_spider", 737: "trapdoor_spider", 738: "fire_ant"}
const Styles := ["original", "rounded", "modern"]
const Renderer := "res://Presentation/SourceModeCreatureVisual.gd"
const FlyingRenderer := "res://Presentation/SourceLaterFlyingVisual.gd"


static func enable() -> Array[int]:
	var enabled: Array[int] = []
	if not FileAccess.file_exists(Manifest):
		return enabled
	var profile: Variant = JSON.parse_string(FileAccess.get_file_as_string(Manifest))
	if not profile is Dictionary or profile.get("schema") != 1:
		return enabled
	var rows: Variant = profile.get("bodies")
	if not rows is Dictionary:
		return enabled
	for body: int in SupportedBodies:
		var current := Registry.entry(body)
		if not current.is_empty() and current.get("kind") != SupportedBodies[body]:
			continue
		var prepared: Variant = rows.get(str(body))
		if not prepared is Dictionary:
			continue
		var hashes: Variant = prepared.get("asset_sha256")
		if not hashes is Dictionary:
			continue
		var assets := checked_scenes(body, hashes)
		if assets.is_empty():
			continue
		var entry: Dictionary = prepared.duplicate(true)
		entry.merge({"kind": SupportedBodies[body], "assets": assets, "status": "validated",
			"presentation_script": FlyingRenderer if body in [718, 733] else Renderer, "profile": "monster",
			"bodies": [{"body": body, "scale": [1.0, 1.0, 1.0], "native_profile": "monster"}]}, true)
		Registry.entries[body] = entry
		enabled.append(body)
	return enabled


static func checked_scenes(body: int, hashes: Dictionary) -> Dictionary:
	var paths := {}
	for style: String in Styles:
		var expected := str(hashes.get(style, ""))
		if not is_digest(expected):
			return {}
		var scene := Manifest.get_base_dir().path_join("%d-%s-%s.scn" % [body, style, expected])
		if not ResourceLoader.exists(scene, "PackedScene") or FileAccess.get_sha256(scene) != expected:
			return {}
		paths[style] = scene
	return paths


static func is_digest(value: String) -> bool:
	if value.length() != 64:
		return false
	for digit: String in value:
		if not "0123456789abcdef".contains(digit):
			return false
	return true
