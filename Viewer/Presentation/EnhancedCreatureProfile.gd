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
		if not matches_base(base, profile.get("base_sha256")) or not valid_groups(profile.get("groups")):
			return {}
		var row := base.duplicate(true)
		row["enhanced_source_action_groups"] = profile.groups
		var assets: Variant = profile.get("assets", {})
		if not assets is Dictionary:
			return {}
		if not assets.is_empty():
			if not profile.get("grounded") is Array or not base.get("archive_grounded_gestures", []) is Array \
				or assets.size() != base.assets.size():
				return {}
			row["asset_sha256"] = {}
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
			if not profile.grounded.is_empty():
				var grounded: Array = row.get("archive_grounded_gestures", [])
				grounded.append_array(profile.grounded)
				row["archive_grounded_gestures"] = grounded
		rows[body] = row
	return rows

static func matches_base(base: Dictionary, expected: Variant) -> bool:
	if not expected is Dictionary or not base.get("assets") is Dictionary or expected.size() != base.assets.size():
		return false
	if base.has("asset_sha256"):
		return base.asset_sha256 == expected
	# Bundled assets have no local acceptance receipt.
	for treatment: String in base.assets:
		var digest := FileAccess.get_sha256(base.assets[treatment])
		if digest.is_empty() or digest != expected.get(treatment):
			return false
	return not expected.is_empty()

static func valid_groups(groups: Variant) -> bool:
	if not groups is Dictionary or groups.size() != 2:
		return false
	var count := 0
	for mode in ["0", "1"]:
		var actions: Variant = groups.get(mode)
		if not actions is Dictionary:
			return false
		for kind: String in actions:
			var clips: Variant = actions[kind]
			if kind not in ["5", "8", "15"] or not clips is Array or clips.is_empty():
				return false
			if not clips.all(func(clip: Variant): return clip is String and not clip.is_empty()):
				return false
			count += 1
	return count > 0
