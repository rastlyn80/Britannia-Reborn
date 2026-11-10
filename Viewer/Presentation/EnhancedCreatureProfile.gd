# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const ART := "res://local-art/creatures/"
const MANIFEST := ART + "enhanced-creature-actions.json"
const SCENES := ART + "enhanced-creature-actions/"
static var enabled := false

static func enable() -> bool:
	if enabled:
		return true
	if not FileAccess.file_exists(MANIFEST):
		return false
	var staged := read_rows(MANIFEST, SCENES)
	if staged.is_empty():
		return false
	for body: int in staged:
		Registry.entries[body] = staged[body]
	enabled = true
	return true

static func read_rows(manifest: String, scene_folder: String) -> Dictionary:
	var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest))
	if not payload is Dictionary or payload.get("schema") != 1 or not payload.get("bodies") is Dictionary:
		return {}
	var rows := {}
	for key: String in payload.bodies:
		if not key.is_valid_int():
			return {}
		var body := int(key)
		var base := Registry.entry(body)
		var profile: Variant = payload.bodies[key]
		if base.is_empty() or not profile is Dictionary or base.get("kind") != profile.get("kind"):
			return {}
		if base.get("asset_sha256") != profile.get("base_sha256") or not valid_groups(profile.get("groups")):
			return {}
		var row := base.duplicate(true)
		row["enhanced_source_action_groups"] = profile.groups
		var assets: Variant = profile.get("assets", {})
		if not assets is Dictionary:
			return {}
		if not assets.is_empty():
			if not profile.get("grounded") is Array or not base.get("archive_grounded_gestures") is Array \
				or assets.size() != base.assets.size():
				return {}
			for treatment: String in base.assets:
				var asset: Variant = assets.get(treatment)
				if not asset is Dictionary:
					return {}
				var path := scene_folder + "%d-%s.scn" % [body, treatment]
				var digest := str(asset.get("sha256", ""))
				if asset.get("path") != path or digest.is_empty() or FileAccess.get_sha256(path) != digest:
					return {}
				row.assets[treatment] = path
				row.asset_sha256[treatment] = digest
			row.archive_grounded_gestures.append_array(profile.grounded)
		rows[body] = row
	return rows

static func valid_groups(groups: Variant) -> bool:
	if not groups is Dictionary or groups.size() != 2:
		return false
	for mode in ["0", "1"]:
		var actions: Variant = groups.get(mode)
		if not actions is Dictionary or not actions.has("5"):
			return false
		for kind: String in actions:
			var clips: Variant = actions[kind]
			if kind not in ["5", "8"] or not clips is Array or clips.is_empty():
				return false
			if not clips.all(func(clip: Variant): return clip is String and not clip.is_empty()):
				return false
	return true
