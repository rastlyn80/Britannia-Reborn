# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Profiles := preload("res://Presentation/SourceLaterCreatureProfile.gd")
const Folder := "res://local-art/creatures/ter-mur-prepared"
const Renderer := "res://Presentation/TerMurCreatureVisual.gd"
const Bodies := {
	293: ["vollem", "Vollem", "construct", 276],
	666: ["gargoyle_male", "Male Gargoyle", "gargoyles", 4],
	667: ["gargoyle_female", "Female Gargoyle", "gargoyles", 4],
	739: ["leather_wolf", "Leather Wolf", "canines", 25],
}


static func enable(folder: String = Folder) -> Array[int]:
	var accepted: Array[int] = []
	var path := folder.path_join("profile.json")
	if not FileAccess.file_exists(path):
		return accepted
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not manifest is Dictionary or manifest.get("schema") != 1 or not manifest.get("bodies") is Dictionary:
		return accepted
	for body: int in Bodies:
		var definition: Array = Bodies[body]
		if not Registry.entry(body).is_empty() and Registry.entry(body).get("kind") != definition[0]:
			continue
		var row: Variant = manifest.bodies.get(str(body))
		if not row is Dictionary or int(row.get("source_body", 0)) != definition[3]:
			continue
		var assets := checked_scenes(folder, body, row.get("asset_sha256"))
		if assets.is_empty():
			continue
		var clips := {"6": "Attack", "10": "Hit", "15": "Fidget", "22": "Walk", "25": "Idle",
			"26": "Fidget", "27": "Fidget", "28": "Fidget"}
		if body != 739:
			clips["19"] = "Fly"
		var equipment := [1, 4, 7, 11, 13, 16, 19, 24] if body in [666, 667] else []
		Registry.entries[body] = {"kind": definition[0], "family": definition[2], "profile": "monster",
			"status": "validated", "presentation_script": Renderer, "assets": assets,
			"bodies": [{"body": body, "name": definition[1], "scale": [1.0, 1.0, 1.0], "native_profile": "monster"}],
			"native_equipment_layers": equipment,
			"classic_action_categories": clips, "new_action_categories": {"5": "Fidget", "14": "Fidget"}}
		accepted.append(body)
	return accepted


static func checked_scenes(folder: String, body: int, hashes: Variant) -> Dictionary:
	if not hashes is Dictionary:
		return {}
	var assets := {}
	for style: String in Profiles.Styles:
		var digest := str(hashes.get(style, ""))
		if not Profiles.is_digest(digest):
			return {}
		var path := folder.path_join("%d-%s-%s.scn" % [body, style, digest])
		if not ResourceLoader.exists(path, "PackedScene") or FileAccess.get_sha256(path) != digest:
			return {}
		assets[style] = path
	return assets
