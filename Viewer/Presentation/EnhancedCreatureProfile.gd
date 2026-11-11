# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Frenzied := preload("res://Presentation/FrenziedOstardProfile.gd")
const ART := "res://local-art/creatures/"
const MANIFEST := ART + "enhanced-creature-actions.json"
const SCENES := ART + "enhanced-creature-actions/"
const UniformAttacks := {88: "MountainGoatQuietStand", 246: "BakeKitsuneLowSnap"}
const SwampMountedIdle := {794: "SwampDragonSeatedStill", 799: "BardedSwampDragonSeatedStill"}
const SwampLowSweep := {794: "SwampDragonWingSweep", 799: "BardedSwampDragonLowSweep"}
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
		if body == Frenzied.Body and base.is_empty():
			base = Frenzied.retained_row()
		var profile: Variant = payload.bodies[key]
		if base.is_empty() or not profile is Dictionary or base.get("kind") != profile.get("kind"):
			return {}
		var base_assets := registered_assets(base)
		if not matches_base(base, base_assets, profile.get("base_sha256")) or not valid_groups(profile.get("groups"), body):
			return {}
		var row := base.duplicate(true)
		row["enhanced_source_action_groups"] = profile.groups
		var flight_fallback: Variant = profile.get("flight_falls_back_to_combat", false)
		if not flight_fallback is bool:
			return {}
		if flight_fallback:
			row["flight_falls_back_to_combat"] = true
		var mounted_idle: Variant = profile.get("mounted_idle", "")
		if mounted_idle != SwampMountedIdle.get(body, ""):
			return {}
		if not str(mounted_idle).is_empty():
			row["enhanced_mounted_idle"] = mounted_idle
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
			elif body in [59, 60]:
				row["presentation_script"] = "res://Presentation/SourceEnhancedDrakeVisual.gd"
			elif body == 221:
				row["presentation_script"] = "res://Presentation/SourceEnhancedWalrusVisual.gd"
			elif body == 89:
				row["presentation_script"] = "res://Presentation/SourceEnhancedIceSerpentVisual.gd"
			elif body == 779:
				row["presentation_script"] = "res://Presentation/SourceEnhancedBoglingVisual.gd"
			elif body == 250:
				row["presentation_script"] = "res://Presentation/SourceEnhancedTsukiWolfVisual.gd"
			elif body == 86:
				row["presentation_script"] = "res://Presentation/SourceEnhancedOphidianVisual.gd"
			elif body == 124:
				row["presentation_script"] = "res://Presentation/SourceEnhancedEvilMageVisual.gd"
			elif body == 775:
				row["presentation_script"] = "res://Presentation/SourceEnhancedPlagueBeastVisual.gd"
			elif body == 240:
				row["presentation_script"] = "res://Presentation/SourceEnhancedKappaVisual.gd"
			elif body == 163:
				row["presentation_script"] = "res://Presentation/SourceEnhancedSnowElementalVisual.gd"
			elif body == 215:
				row["presentation_script"] = "res://Presentation/SourceEnhancedGiantRatVisual.gd"
			elif body == 317:
				row["presentation_script"] = "res://Presentation/SourceEnhancedVampireBatVisual.gd"
			elif body == 213:
				row["presentation_script"] = "res://Presentation/SourceEnhancedPolarBearVisual.gd"
			elif body == 208:
				row["presentation_script"] = "res://Presentation/SourceEnhancedChickenVisual.gd"
			elif body == 85:
				row["presentation_script"] = "res://Presentation/SourceEnhancedOphidianMageVisual.gd"
				row["grounded_gestures"] = row.get("grounded_gestures", []) + profile.grounded
			elif body in [140, 147, 148]:
				row["presentation_script"] = "res://Presentation/SourceEnhancedSkeletalMageVisual.gd"
			elif body == 158:
				row["presentation_script"] = "res://Presentation/SourceEnhancedAcidElementalVisual.gd"
			elif body == 128:
				row["presentation_script"] = "res://Presentation/SourceEnhancedPixieVisual.gd"
			elif body == 55:
				row["presentation_script"] = "res://Presentation/SourceEnhancedFrostTrollVisual.gd"
			elif body == 162:
				row["presentation_script"] = "res://Presentation/SourceEnhancedPoisonElementalVisual.gd"
			elif body == 11:
				row["presentation_script"] = "res://Presentation/SourceEnhancedDreadSpiderVisual.gd"
			elif body == 154:
				row["presentation_script"] = "res://Presentation/SourceEnhancedMummyVisual.gd"
			elif body == 40:
				row["presentation_script"] = "res://Presentation/SourceEnhancedBalronVisual.gd"
			elif body == 80:
				row["presentation_script"] = "res://Presentation/SourceEnhancedGiantToadVisual.gd"
			elif body == 245:
				row["presentation_script"] = "res://Presentation/SourceEnhancedYomotsuWarriorVisual.gd"
			elif body == 143:
				row["presentation_script"] = "res://Presentation/SourceEnhancedRatmanMageVisual.gd"
			elif body == 90:
				row["presentation_script"] = "res://Presentation/SourceEnhancedLavaSerpentVisual.gd"
			elif body == 75:
				row["presentation_script"] = "res://Presentation/SourceEnhancedCyclopsVisual.gd"
			elif body == 76:
				row["presentation_script"] = "res://Presentation/SourceEnhancedTitanVisual.gd"
			elif body == 161:
				row["presentation_script"] = "res://Presentation/SourceEnhancedIceElementalVisual.gd"
			elif body in [70, 71]:
				row["presentation_script"] = "res://Presentation/SourceEnhancedTerathanVisual.gd"
			elif body == 302:
				row["presentation_script"] = "res://Presentation/SourceEnhancedHopperVisual.gd"
			elif body == 247:
				row["presentation_script"] = "res://Presentation/SourceEnhancedFanDancerVisual.gd"
			elif body == 159:
				row["presentation_script"] = "res://Presentation/SourceEnhancedBloodElementalVisual.gd"
			elif body == 88:
				row["presentation_script"] = "res://Presentation/SourceEnhancedMountainGoatVisual.gd"
			elif body == 87:
				row["presentation_script"] = "res://Presentation/SourceEnhancedMatriarchVisual.gd"
			elif body == 149:
				row["presentation_script"] = "res://Presentation/SourceEnhancedSuccubusVisual.gd"
			elif body == 73:
				row["presentation_script"] = "res://Presentation/SourceEnhancedStoneHarpyVisual.gd"
			elif body == 776:
				row["presentation_script"] = "res://Presentation/SourceEnhancedHordeMinionVisual.gd"
			elif body == 67:
				row["presentation_script"] = "res://Presentation/SourceEnhancedStoneGargoyleVisual.gd"
			elif body == 246:
				row["presentation_script"] = "res://Presentation/SourceEnhancedBakeKitsuneVisual.gd"
			elif body == 7:
				row["presentation_script"] = "res://Presentation/SourceEnhancedOrcCaptainVisual.gd"
			elif body == 805:
				row["presentation_script"] = "res://Presentation/SourceEnhancedBlackSolenWorkerVisual.gd"
			elif body == 131:
				row["presentation_script"] = "res://Presentation/SourceEnhancedEfreetVisual.gd"
			elif body == 152:
				row["presentation_script"] = "res://Presentation/SourceEnhancedTerathanAvengerVisual.gd"
			elif body == 155:
				row["presentation_script"] = "res://Presentation/SourceEnhancedRottingCorpseVisual.gd"
			elif body == 780:
				row["presentation_script"] = "res://Presentation/SourceEnhancedBogThingVisual.gd"
			elif body in [259, 264]:
				row["presentation_script"] = "res://Presentation/SourceEnhancedGrizzleChangelingVisual.gd"
			elif body == 72:
				row["presentation_script"] = "res://Presentation/SourceEnhancedTerathanMatriarchVisual.gd"
				row["grounded_gestures"] = row.get("grounded_gestures", []) + profile.grounded
			elif body in [794, 799]:
				row["presentation_script"] = "res://Presentation/SourceEnhancedSwampDragonVisual.gd"
			elif body == 157:
				row["presentation_script"] = "res://Presentation/SourceEnhancedBlackWidowVisual.gd"
			elif body == 765:
				row["presentation_script"] = "res://Presentation/SourceEnhancedJukaMageVisual.gd"
			elif body == 182:
				row["presentation_script"] = "res://Presentation/SourceEnhancedOrcBomberVisual.gd"
			elif body == 83:
				row["presentation_script"] = "res://Presentation/SourceEnhancedOgreLordVisual.gd"
			elif body == 730:
				row["presentation_script"] = "res://Presentation/SourceEnhancedRaptorVisual.gd"
			elif body == 734:
				row["presentation_script"] = "res://Presentation/SourceEnhancedSlithVisual.gd"
			elif body == Frenzied.Body:
				row["presentation_script"] = Frenzied.Renderer
			elif body == 251:
				row["presentation_script"] = "res://Presentation/SourceEnhancedRevenantLionVisual.gd"
			elif body == 168:
				row["presentation_script"] = "res://Presentation/SourceEnhancedShadowFiendVisual.gd"
			elif body == 243:
				row["presentation_script"] = "res://Presentation/SourceEnhancedHiryuVisual.gd"
			elif body == 787:
				row["presentation_script"] = "res://Presentation/SourceEnhancedAntLionVisual.gd"
			elif body == 300:
				row["presentation_script"] = "res://Presentation/SourceEnhancedCrystalElementalVisual.gd"
			elif body == 263:
				row["presentation_script"] = "res://Presentation/SourceEnhancedMinotaurVisual.gd"
			elif body == 305:
				row["presentation_script"] = "res://Presentation/SourceEnhancedGoreFiendVisual.gd"
			elif body == 20:
				row["presentation_script"] = "res://Presentation/SourceEnhancedFrostSpiderVisual.gd"
			elif body == 303:
				row["presentation_script"] = "res://Presentation/SourceEnhancedDevourerVisual.gd"
			elif body == 806:
				row["presentation_script"] = "res://Presentation/SourceEnhancedBlackSolenWarriorVisual.gd"
			elif body == 766:
				row["presentation_script"] = "res://Presentation/SourceEnhancedJukaLordVisual.gd"
			elif body == 752:
				row["presentation_script"] = "res://Presentation/SourceEnhancedIronGolemVisual.gd"
			elif body == 790:
				row["presentation_script"] = "res://Presentation/SourceEnhancedSandVortexVisual.gd"
			elif body == 244:
				row["presentation_script"] = "res://Presentation/SourceEnhancedRuneBeetleVisual.gd"
			elif body == 777:
				row["presentation_script"] = "res://Presentation/SourceEnhancedDopplegangerVisual.gd"
			elif body == 764:
				row["presentation_script"] = "res://Presentation/SourceEnhancedJukaWarriorVisual.gd"
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

static func valid_groups(groups: Variant, body: int) -> bool:
	if not groups is Dictionary or groups.size() != 2:
		return false
	var count := 0
	for mode in ["0", "1"]:
		var actions: Variant = groups.get(mode)
		if not actions is Dictionary:
			return false
		for kind: String in actions:
			var clips: Variant = actions[kind]
			if not clips is Array or clips.is_empty():
				return false
			if kind == "0":
				# Each named record selects one verified clip for every weapon subaction.
				var expected: String = UniformAttacks.get(body, "")
				if expected.is_empty() or mode != "0" or clips.size() != 6:
					return false
				if clips.any(func(clip: Variant): return clip != expected):
					return false
			elif kind == "1":
				if mode != "0" or not SwampLowSweep.has(body) or clips != [SwampLowSweep[body], SwampLowSweep[body]]:
					return false
			elif kind not in ["2", "5", "8", "11", "14", "15"]:
				return false
			if not clips.all(func(clip: Variant): return clip is String and not clip.is_empty()):
				return false
			count += 1
	return count > 0
