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
		var base_assets := registered_assets(base)
		if not matches_base(base, base_assets, profile.get("base_sha256")) or not valid_groups(profile.get("groups")):
			return {}
		var row := base.duplicate(true)
		row["enhanced_source_action_groups"] = profile.groups
		var flight_fallback: Variant = profile.get("flight_falls_back_to_combat", false)
		if not flight_fallback is bool:
			return {}
		if flight_fallback:
			row["flight_falls_back_to_combat"] = true
		var assets: Variant = profile.get("assets", {})
		if not assets is Dictionary:
			return {}
		if not assets.is_empty():
			if not profile.get("grounded") is Array or not base.get("archive_grounded_gestures", []) is Array \
				or assets.size() != base_assets.size():
				return {}
			row["asset_sha256"] = {}
			row["assets"] = {}
			for treatment: String in base_assets:
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
			if body in [53, 54]:
				row["presentation_script"] = "res://Presentation/SourceEnhancedTrollVisual.gd"
			elif body == 42:
				row["presentation_script"] = "res://Presentation/SourceEnhancedRatmanVisual.gd"
			elif body == 18:
				row["presentation_script"] = "res://Presentation/SourceEnhancedEttinVisual.gd"
			elif body == 205:
				row["presentation_script"] = "res://Presentation/SourceEnhancedRabbitVisual.gd"
			elif body == 3:
				row["presentation_script"] = "res://Presentation/SourceEnhancedZombieVisual.gd"
			elif body == 26:
				row["presentation_script"] = "res://Presentation/SourceEnhancedWraithVisual.gd"
			elif body == 29:
				row["presentation_script"] = "res://Presentation/SourceEnhancedGorillaVisual.gd"
			elif body == 22:
				row["presentation_script"] = "res://Presentation/SourceEnhancedGazerVisual.gd"
			elif body == 4:
				row["presentation_script"] = "res://Presentation/SourceEnhancedGargoyleVisual.gd"
			elif body == 31:
				row["presentation_script"] = "res://Presentation/SourceEnhancedHeadlessVisual.gd"
			elif body == 74:
				row["presentation_script"] = "res://Presentation/SourceEnhancedImpVisual.gd"
			elif body == 153:
				row["presentation_script"] = "res://Presentation/SourceEnhancedGhoulVisual.gd"
			elif body == 48:
				row["presentation_script"] = "res://Presentation/SourceEnhancedScorpionVisual.gd"
			elif body == 242:
				row["presentation_script"] = "res://Presentation/SourceEnhancedDeathwatchVisual.gd"
			elif body == 13:
				row["presentation_script"] = "res://Presentation/SourceEnhancedAirVisual.gd"
			elif body == 51:
				row["presentation_script"] = "res://Presentation/SourceEnhancedSlimeVisual.gd"
			elif body == 202:
				row["presentation_script"] = "res://Presentation/SourceEnhancedAlligatorVisual.gd"
			elif body == 23:
				row["presentation_script"] = "res://Presentation/SourceEnhancedDireWolfVisual.gd"
			elif body == 254:
				row["presentation_script"] = "res://Presentation/SourceEnhancedCraneVisual.gd"
			elif body == 15:
				row["presentation_script"] = "res://Presentation/SourceEnhancedFireVisual.gd"
			elif body == 24:
				row["presentation_script"] = "res://Presentation/SourceEnhancedLichVisual.gd"
			elif body == 248:
				row["presentation_script"] = "res://Presentation/SourceEnhancedGamanVisual.gd"
			elif body in [9, 62]:
				row["presentation_script"] = "res://Presentation/SourceEnhancedWingedVisual.gd"
			elif body == 213:
				row["presentation_script"] = "res://Presentation/SourceEnhancedPolarBearVisual.gd"
			elif body == 208:
				row["presentation_script"] = "res://Presentation/SourceEnhancedChickenVisual.gd"
			elif body == 148:
				row["presentation_script"] = "res://Presentation/SourceEnhancedSkeletalMageVisual.gd"
			elif body == 8:
				row["presentation_script"] = "res://Presentation/SourceEnhancedCorpserVisual.gd"
			elif body == 14:
				row["presentation_script"] = "res://Presentation/SourceEnhancedEarthVisual.gd"
			elif body == 21:
				row["presentation_script"] = "res://Presentation/SourceEnhancedSerpentVisual.gd"
			elif body == 30:
				row["presentation_script"] = "res://Presentation/SourceEnhancedHarpyVisual.gd"
			elif body in [1, 25, 63, 167, 207, 209, 211, 212, 217, 223, 234, 237, 290]:
				row["presentation_script"] = "res://Presentation/SourceEnhancedFieldVisual.gd"
			elif body == 50:
				row["presentation_script"] = "res://Presentation/SourceEnhancedSkeletonVisual.gd"
			elif body == 39:
				row["presentation_script"] = "res://Presentation/SourceEnhancedMongbatVisual.gd"
		rows[body] = row
	return rows

static func registered_assets(base: Dictionary) -> Dictionary:
	var assets: Variant = base.get("assets", {})
	if assets is Dictionary and not assets.is_empty():
		return assets
	var digests: Variant = base.get("asset_sha256")
	var paths := {}
	if digests is Dictionary:
		for treatment: String in digests:
			if treatment not in ["original", "rounded", "modern"]:
				return {}
			paths[treatment] = Registry.asset_path(base, treatment)
	return paths

static func matches_base(base: Dictionary, assets: Dictionary, expected: Variant) -> bool:
	if not expected is Dictionary or assets.is_empty() or expected.size() != assets.size():
		return false
	var pins: Variant = base.get("asset_sha256")
	if pins is Dictionary:
		return pins == expected
	if pins != null and (not pins is String or assets.size() != 1 or pins != expected.values()[0]):
		return false
	# Bundled entries may pin one public model instead of a treatment dictionary.
	for treatment: String in assets:
		var digest := FileAccess.get_sha256(assets[treatment])
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
			if kind not in ["2", "5", "8", "11", "14", "15"] or not clips is Array or clips.is_empty():
				return false
			if not clips.all(func(clip: Variant): return clip is String and not clip.is_empty()):
				return false
			count += 1
	return count > 0
