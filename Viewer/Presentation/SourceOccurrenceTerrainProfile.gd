# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const RabbitBody := 205
const RabbitBase := "res://Presentation/RabbitActionsVisual.gd"
const RabbitTerrain := "res://Presentation/SourceTerrainRabbitVisual.gd"
const RabbitEnhanced := "res://Presentation/SourceEnhancedRabbitVisual.gd"
const RabbitEnhancedTerrain := "res://Presentation/SourceEnhancedTerrainRabbitVisual.gd"
const RabbitArt := "res://Art/Creatures/Rabbit/rabbit.glb"
const RabbitProvenance := "res://Art/Creatures/Rabbit/provenance.json"
const RatScene := "res://Art/Creatures/Rat/rat-deaths.scn"
const RatEnhanced := "res://Presentation/SourceEnhancedOrdinaryRatVisual.gd"
const ChickenArt := "res://Art/Creatures/Chicken/"
const OwnedForms := {
	208: [ChickenArt + "chicken.glb", ChickenArt + "provenance.json", "res://Presentation/ChickenActionsVisual.gd"],
	15: ["res://Art/Creatures/Fire/fire-elemental.scn", "res://Art/Creatures/Fire/provenance.json",
		"res://Presentation/FireActionsVisual.gd"],
	6: ["res://Art/Creatures/Birds/small-bird.glb", "res://Art/Creatures/Birds/preparation.json", ""],
	779: ["res://Art/Creatures/Bogling/bogling.glb", "res://Art/Creatures/Bogling/provenance.json",
		"res://Presentation/BoglingActionsVisual.gd"],
	13: ["res://Art/Creatures/Air/air-elemental.scn", "res://Art/Creatures/Air/provenance.json",
		"res://Presentation/AirActionsVisual.gd"],
	58: ["res://Art/Creatures/Wisp/wisp.scn", "res://Art/Creatures/Wisp/provenance.json",
		"res://Presentation/WispActionsVisual.gd"],
}
const OrcLord := 138
const OrcLordAssets := "res://local-art/creatures/orc-lord-prepared"
const OrcLordRenderer := "res://Presentation/SourceTerrainOrcishLordVisual.gd"
const Forms := {
	81: ["frogs_bullfrog", "res://Presentation/SourceTerrainFrogVisual.gd"],
	238: ["rat_ordinary", "res://Presentation/SourceTerrainOrdinaryRatVisual.gd"],
	62: ["dragons_wyvern", "res://Presentation/SourceTerrainWyvernVisual.gd"],
	221: ["walrus_walrus_male", "res://Presentation/SourceTerrainWalrusVisual.gd"],
	163: ["elementals_snow_elemental", "res://Presentation/SourceTerrainSnowElementalVisual.gd"],
	9: ["daemons_daemon_slot11_9", "res://Presentation/SourceTerrainDaemonVisual.gd"],
	60: ["dragons_dragon_blasted_slot11_60", "res://Presentation/SourceTerrainDrakeVisual.gd"],
	61: ["dragons_dragon_blasted_red_slot11_61", "res://Presentation/SourceTerrainDrakeVisual.gd"],
	89: ["serpents_snake_giant_ice", "res://Presentation/SourceTerrainIceSerpentVisual.gd"],
	24: ["liche_liche_retro", "res://Presentation/SourceTerrainLichVisual.gd"],
	208: ["chicken", "res://Presentation/SourceTerrainChickenVisual.gd"],
	52: ["small_snakes", "res://Presentation/SourceTerrainSmallSnakeVisual.gd"],
	15: ["fire_elemental", "res://Presentation/SourceTerrainFireElementalVisual.gd"],
	6: ["birds_small", "res://Presentation/SourceTerrainTropicalBirdVisual.gd"],
	779: ["bogling", "res://Presentation/SourceTerrainBoglingVisual.gd"],
	31: ["headless_headless", "res://Presentation/SourceTerrainHeadlessVisual.gd"],
	13: ["air_elemental", "res://Presentation/SourceTerrainAirElementalVisual.gd"],
	58: ["wisp", "res://Presentation/SourceTerrainWispVisual.gd"],
	29: ["gorillas_silverback", "res://Presentation/SourceTerrainGorillaVisual.gd"],
	153: ["walking_dead_ghoul", "res://Presentation/SourceTerrainGhoulVisual.gd"],
	1: ["ogres_ogre", "res://Presentation/SourceTerrainOgreVisual.gd"],
	3: ["walking_dead_zombie", "res://Presentation/SourceTerrainZombieVisual.gd"],
	8: ["flails_corpser", "res://Presentation/SourceTerrainCorpserVisual.gd"],
	21: ["serpents_snake_giant", "res://Presentation/SourceTerrainGiantSerpentVisual.gd"],
	22: ["gazers_gazer", "res://Presentation/SourceTerrainGazerVisual.gd"],
	30: ["harpies_harpy", "res://Presentation/SourceTerrainHarpyVisual.gd"],
	39: ["mongbats_mongbat", "res://Presentation/SourceMongbatTerrainVisual.gd"],
	47: ["flails_reaper", "res://Presentation/SourceReaperGroundVisual.gd"],
}


static func enable() -> Array[int]:
	var enabled: Array[int] = []
	for body: int in Forms:
		var row := Registry.entry(body)
		if row.get("kind") != Forms[body][0] or not ready_for_terrain(body, row):
			continue
		var prepared := row.duplicate()
		prepared.presentation_script = Forms[body][1]
		Registry.entries[body] = prepared
		enabled.append(body)
	if enable_orc_lord():
		enabled.append(OrcLord)
	enable_bog_clock()
	if enable_rabbit():
		enabled.append(RabbitBody)
	return enabled


static func ready_for_terrain(body: int, row: Dictionary) -> bool:
	if body == 238:
		return checked_rat(row)
	if checked_owned(body, row):
		return body != 208 or checked_chicken_actions(row)
	if body == 13:
		var renderer: String = row.get("presentation_script", "")
		return (renderer in ["res://Presentation/SourceEnhancedAirVisual.gd", Forms[body][1]]
			and Registry.asset_path(row) == "res://local-art/creatures/enhanced-creature-actions/13-modern.scn"
			and checked_asset(row, "modern"))
	if body == 15:
		var renderer: String = row.get("presentation_script", "")
		return (renderer in ["res://Presentation/SourceEnhancedFireVisual.gd", Forms[body][1]]
			and Registry.asset_path(row) == "res://local-art/creatures/enhanced-creature-actions/15-modern.scn"
			and checked_asset(row, "modern"))
	if body in [6, 208, 779]:
		return Registry.asset_path(row) == "res://local-art/creatures/enhanced-creature-actions/%d-modern.scn" % body \
			and checked_asset(row, "modern")
	return checked_assets(row)


static func checked_rat(row: Dictionary) -> bool:
	var renderer: String = row.get("presentation_script", "")
	var path := Registry.asset_path(row)
	if renderer not in ["res://Presentation/FieldClassicCollapseVisual.gd", RatEnhanced, Forms[238][1]]:
		return false
	if path != RatScene:
		return path == "res://local-art/creatures/ordinary-rat-enhanced/rat-enhanced.scn" and checked_asset(row, "modern")
	var provenance: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://Art/Creatures/Rat/deaths-provenance.json"))
	return provenance is Dictionary and ResourceLoader.exists(path, "PackedScene") \
		and FileAccess.get_sha256(path) == provenance.get("scene_sha256", "")

static func checked_owned(body: int, row: Dictionary) -> bool:
	if not OwnedForms.has(body):
		return false
	var form: Array = OwnedForms[body]
	var path := Registry.asset_path(row)
	var renderer: String = row.get("presentation_script", "")
	if path != form[0] or renderer not in [form[2], Forms[body][1]] or not ResourceLoader.exists(path, "PackedScene"):
		return false
	var provenance: Variant = JSON.parse_string(FileAccess.get_file_as_string(form[1]))
	if not provenance is Dictionary:
		return false
	var digest: String = provenance.get("asset_sha256", "")
	return digest.length() == 64 and row.get("asset_sha256", digest) == digest and FileAccess.get_sha256(path) == digest


static func checked_chicken_actions(row: Dictionary) -> bool:
	var library := ChickenArt + "distinct-actions.res"
	if row.get("additional_animation_library", "") != library or not ResourceLoader.exists(library, "AnimationLibrary"):
		return false
	var provenance: Variant = JSON.parse_string(FileAccess.get_file_as_string(ChickenArt + "distinct-actions-provenance.json"))
	return provenance is Dictionary and FileAccess.get_sha256(library) == provenance.get("animation_library_sha256", "")


static func checked_assets(row: Dictionary) -> bool:
	for treatment: String in ["original", "rounded", "modern"]:
		if not checked_asset(row, treatment):
			return false
	return true


static func checked_asset(row: Dictionary, treatment: String) -> bool:
	var path := Registry.asset_path(row, treatment)
	var digests: Variant = row.get("asset_sha256")
	if not digests is Dictionary:
		return false
	var digest: String = digests.get(treatment, "")
	return (digest.length() == 64 and ResourceLoader.exists(path, "PackedScene")
		and FileAccess.get_sha256(path) == digest)


static func enable_rabbit() -> bool:
	var row := Registry.entry(RabbitBody)
	if row.get("kind") != "rabbit":
		return false
	var renderer: String = row.get("presentation_script", "")
	if renderer in [RabbitEnhanced, RabbitEnhancedTerrain]:
		if Registry.asset_path(row) != "res://local-art/creatures/enhanced-creature-actions/205-modern.scn" \
				or not checked_asset(row, "modern"):
			return false
		if renderer == RabbitEnhanced:
			var prepared := row.duplicate()
			prepared.presentation_script = RabbitEnhancedTerrain
			Registry.entries[RabbitBody] = prepared
		return true
	if renderer not in [RabbitBase, RabbitTerrain] or Registry.asset_path(row) != RabbitArt:
		return false
	var provenance: Variant = JSON.parse_string(FileAccess.get_file_as_string(RabbitProvenance))
	if not provenance is Dictionary or not ResourceLoader.exists(RabbitArt, "PackedScene"):
		return false
	var digest: String = provenance.get("asset_sha256", "")
	if digest.length() != 64 or FileAccess.get_sha256(RabbitArt) != digest:
		return false
	var prepared := row.duplicate()
	prepared.presentation_script = RabbitTerrain
	Registry.entries[RabbitBody] = prepared
	return true



static func enable_bog_clock() -> void:
	const Body := 780
	var row := Registry.entry(Body)
	if row.get("kind") != "bog_thing":
		return
	var renderer: String = row.get("presentation_script", "")
	var path := Registry.asset_path(row)
	var script: String
	if renderer == "res://Presentation/BogThingActionsVisual.gd" and path == "res://local-art/creatures/bog-thing-actions.scn":
		var digest: String = row.get("authored_action_scene_sha256", {}).get("modern", "")
		if digest.length() == 64 and FileAccess.get_sha256(path) == digest:
			script = "res://Presentation/SourceClockBogThingVisual.gd"
	elif renderer == "res://Presentation/SourceEnhancedBogThingVisual.gd" \
			and path == "res://local-art/creatures/enhanced-creature-actions/780-modern.scn" and checked_asset(row, "modern"):
		script = "res://Presentation/SourceEnhancedClockBogThingVisual.gd"
	if not script.is_empty():
		var prepared := row.duplicate()
		prepared.presentation_script = script
		Registry.entries[Body] = prepared



static func enable_orc_lord() -> bool:
	var row := Registry.entry(OrcLord)
	if row.get("kind") != "orcs_orc_lord":
		return false
	if row.get("presentation_script", "") == OrcLordRenderer:
		return checked_assets(row)
	var manifest_path := OrcLordAssets + "/manifest.json"
	if not FileAccess.file_exists(manifest_path) or not checked_assets(row):
		return false
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not manifest is Dictionary or manifest.get("schema") != 1 or manifest.get("body") != OrcLord:
		return false
	var sources: Variant = manifest.get("base")
	var scenes: Variant = manifest.get("assets")
	if not sources is Dictionary or not scenes is Dictionary or sources != row.get("asset_sha256"):
		return false
	var assets := {}
	for treatment: String in ["original", "rounded", "modern"]:
		var path := OrcLordAssets.path_join("orc-lord-axe-%s.scn" % treatment)
		var digest: String = scenes.get(treatment, "")
		if digest.length() != 64 or FileAccess.get_sha256(path) != digest or not ResourceLoader.exists(path, "PackedScene"):
			return false
		assets[treatment] = path
	var prepared := row.duplicate()
	prepared.assets = assets
	prepared.asset_sha256 = scenes
	prepared.presentation_script = OrcLordRenderer
	Registry.entries[OrcLord] = prepared
	return true
