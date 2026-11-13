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
	752: ["golem_iron", "res://Presentation/SourceTerrainGolemVisual.gd"],
	165: ["shadow_wisp", "res://Presentation/SourceTerrainShadowWispVisual.gd"],
	20: ["arachnids_spider_frost", "res://Presentation/SourceTerrainFrostSpiderVisual.gd"],
	94: ["slimes_slime_frost", "res://Presentation/SourceTerrainFrostOozeVisual.gd"],
	123: ["ethereal_warriors_male", "res://Presentation/SourceTerrainLatticeSeekerVisual.gd"],
	791: ["giant_beetle", "res://Presentation/SourceTerrainGiantBeetleVisual.gd"],
	130: ["gargoyles_gargoyle_blistering", "res://Presentation/SourceTerrainFireGargoyleVisual.gd"],
	792: ["chaos_demon", "res://Presentation/SourceTerrainChaosDaemonVisual.gd"],
	785: ["four_armed_demon", "res://Presentation/SourceTerrainMolochVisual.gd"],
	189: ["orcs_orc_brute", "res://Presentation/SourceTerrainOrcBruteVisual.gd"],
	807: ["black_ant_queen", "res://Presentation/SourceTerrainBlackSolenQueenVisual.gd"],
	784: ["arcane_demon", "res://Presentation/SourceTerrainCrystalDaemonVisual.gd"],
	266: ["dryad", "res://Presentation/SourceTerrainDryadVisual.gd"],
	267: ["troglodyte", "res://Presentation/SourceTerrainTroglodyteVisual.gd"],
	755: ["gargoyles_gargoyle_guard", "res://Presentation/SourceTerrainArmoredGargoyleVisual.gd"],
	754: ["gargoyles_gargoyle_enforcer", "res://Presentation/SourceTerrainArmoredGargoyleVisual.gd"],
	135: ["ogres_ogre_lord_arctic", "res://Presentation/SourceTerrainArcticOgreLordVisual.gd"],
	43: ["daemons_daemon_ice_fiend", "res://Presentation/SourceTerrainIceFiendVisual.gd"],
	783: ["fire_ant_queen", "res://Presentation/SourceTerrainRedSolenQueenVisual.gd"],
	155: ["walking_dead_rotting_corpse", "res://Presentation/SourceTerrainRottingCorpseVisual.gd"],
	106: ["dragons_wyrm_shadow", "res://Presentation/SourceTerrainShadowWyrmVisual.gd"],
	279: ["ferret", "res://Presentation/SourceTerrainFerretVisual.gd"],
	265: ["hydra", "res://Presentation/SourceTerrainHydraVisual.gd"],
	202: ["lizards_alligator_brown", "res://Presentation/SourceTerrainThrasherVisual.gd"],
	46: ["dragons_wyrm_ancient", "res://Presentation/SourceTerrainAncientWyrmVisual.gd"],
	49: ["dragons_dragon_ice", "res://Presentation/SourceTerrainWhiteWyrmVisual.gd"],
	180: ["dragons_dragon_ice", "res://Presentation/SourceTerrainWhiteWyrmVisual.gd"],
	254: ["crane", "res://Presentation/SourceTerrainCraneVisual.gd"],
	242: ["bimbobushi", "res://Presentation/SourceTerrainDeathwatchBeetleVisual.gd"],
	250: ["tri_wolf", "res://Presentation/SourceTerrainTsukiWolfVisual.gd"],
	240: ["kappa", "res://Presentation/SourceTerrainKappaVisual.gd"],
	317: ["vampire_bat", "res://Presentation/SourceTerrainVampireBatVisual.gd"],
	128: ["fey_race_pixie", "res://Presentation/SourceTerrainPixieVisual.gd"],
	245: ["yomotsu_warrior", "res://Presentation/SourceTerrainYomotsuWarriorVisual.gd"],
	309: ["patchskeleton", "res://Presentation/SourceTerrainPatchworkSkeletonVisual.gd"],
	196: ["denkou_yajuu", "res://Presentation/SourceTerrainKazeKemonoVisual.gd"],
	302: ["skittering_hopper", "res://Presentation/SourceTerrainHopperVisual.gd"],
	247: ["fan_dancer", "res://Presentation/SourceTerrainFanDancerVisual.gd"],
	88: ["ruminants_goat_mountain", "res://Presentation/SourceTerrainMountainGoatVisual.gd"],
	776: ["horde_demon", "res://Presentation/SourceTerrainHordeMinionVisual.gd"],
	246: ["kitsun_tsuki", "res://Presentation/SourceTerrainBakeKitsuneVisual.gd"],
	734: ["lizards_komodo_dragon", "res://Presentation/SourceTerrainSlithVisual.gd"],
	157: ["arachnids_spider_black_widow", "res://Presentation/SourceTerrainBlackWidowVisual.gd"],
	244: ["rune_beetle", "res://Presentation/SourceTerrainRuneBeetleVisual.gd"],
	730: ["raptor", "res://Presentation/SourceTerrainRaptorVisual.gd"],
	790: ["sand_vortex", "res://Presentation/SourceTerrainSandVortexVisual.gd"],
	303: ["devourer", "res://Presentation/SourceTerrainDevourerVisual.gd"],
	251: ["vampyric_beast", "res://Presentation/SourceTerrainRevenantLionVisual.gd"],
	168: ["imps_shadow_fiend", "res://Presentation/SourceTerrainShadowFiendVisual.gd"],
	243: ["hai_riyo", "res://Presentation/SourceTerrainHiryuVisual.gd"],
	300: ["crystal_elemental", "res://Presentation/SourceTerrainCrystalElementalVisual.gd"],
	263: ["minotaur", "res://Presentation/SourceTerrainMinotaurVisual.gd"],
	253: ["yomotsu_priest", "res://Presentation/SourceTerrainYomotsuPriestVisual.gd"],
	305: ["gore_fiend", "res://Presentation/SourceTerrainGoreFiendVisual.gd"],
	771: ["meer_warrior", "res://Presentation/SourceTerrainMeerWarriorVisual.gd"],
	281: ["leatherminotaur", "res://Presentation/SourceTerrainMinotaurScoutVisual.gd"],
	241: ["oni", "res://Presentation/SourceTerrainOniVisual.gd"],
	770: ["meer_mage", "res://Presentation/SourceTerrainMeerMageVisual.gd"],
	301: ["treefellow", "res://Presentation/SourceTerrainTreefellowVisual.gd"],
	92: ["serpents_snake_giant_silver", "res://Presentation/SourceTerrainSilverSerpentVisual.gd"],
	277: ["cushidhe", "res://Presentation/SourceTerrainCuSidheVisual.gd"],
	773: ["npc_cpt_dasha", "res://Presentation/SourceTerrainMeerCaptainVisual.gd"],
	789: ["quagmire", "res://Presentation/SourceTerrainQuagmireVisual.gd"],
	772: ["npc_adranath", "res://Presentation/SourceTerrainMeerEternalVisual.gd"],
	304: ["flesh_golem", "res://Presentation/SourceTerrainFleshGolemVisual.gd"],
	757: ["clockwork_minion", "res://Presentation/SourceTerrainExodusMinionVisual.gd"],
	756: ["clockwork_overseer", "res://Presentation/SourceTerrainExodusOverseerVisual.gd"],
	252: ["lady_of_the_snow", "res://Presentation/SourceTerrainSnowLadyVisual.gd"],
	199: ["gouzen_ha", "res://Presentation/SourceTerrainRaiJuVisual.gd"],
	271: ["satyr", "res://Presentation/SourceTerrainSatyrVisual.gd"],
	310: ["wailingbanshee", "res://Presentation/SourceTerrainWailingBansheeVisual.gd"],
	280: ["minotaurarmored", "res://Presentation/SourceTerrainMinotaurCaptainVisual.gd"],
	278: ["squirrel", "res://Presentation/SourceTerrainSquirrelVisual.gd"],
	767: ["npc_blackthorn_cohort", "res://Presentation/SourceTerrainBetrayerVisual.gd"],
	768: ["juggernaut", "res://Presentation/SourceTerrainJuggernautVisual.gd"],
	307: ["gibberling", "res://Presentation/SourceTerrainGibberlingVisual.gd"],
	249: ["yamandon", "res://Presentation/SourceTerrainYamandonVisual.gd"],
	78: ["liche_liche_lord_retro", "res://Presentation/SourceTerrainAncientLichVisual.gd"],
	308: ["bonedemon", "res://Presentation/SourceTerrainBoneDemonVisual.gd"],
	753: ["gargoyles_gargoyle_slave", "res://Presentation/SourceTerrainEnslavedGargoyleVisual.gd"],
	129: ["flails_swamp_tentacles", "res://Presentation/SourceTerrainHarrowerTentaclesVisual.gd"],
	218: ["frenzied", "res://Presentation/SourceTerrainFrenziedOstardVisual.gd"],
	66: ["flails_swamp_tentacles_actions_66", "res://Presentation/SourceTerrainSwampTentacleVisual.gd"],
	766: ["npc_kabur", "res://Presentation/SourceTerrainJukaLordVisual.gd"],
	765: ["juka_mage", "res://Presentation/SourceTerrainJukaMageVisual.gd"],
	787: ["ant_lion", "res://Presentation/SourceTerrainAntLionVisual.gd"],
	79: ["liche_liche_lord_retro_actions_79", "res://Presentation/SourceTerrainLichLordVisual.gd"],
	131: ["genies_efreet", "res://Presentation/SourceTerrainEfreetVisual.gd"],
	264: ["changling", "res://Presentation/SourceTerrainChangelingVisual.gd"],
	777: ["doppleganger", "res://Presentation/SourceTerrainDopplegangerVisual.gd"],
	83: ["ogres_ogre_lord_slot11_83", "res://Presentation/SourceTerrainOgreLordVisual.gd"],
	259: ["monstrousinterredgrizzle", "res://Presentation/SourceTerrainInterredGrizzleVisual.gd"],
	182: ["orcs_orc_bomber", "res://Presentation/SourceTerrainOrcBomberVisual.gd"],
	148: ["skeletons_skeleton_mage", "res://Presentation/SourceTerrainBoneMagiVisual.gd"],
	159: ["elementals_blood_elemental", "res://Presentation/SourceTerrainBloodElementalVisual.gd"],
	7: ["orcs_orc_captain", "res://Presentation/SourceTerrainOrcCaptainVisual.gd"],
	90: ["serpents_snake_giant_lava", "res://Presentation/SourceTerrainLavaSerpentVisual.gd"],
	67: ["gargoyles_gargoyle_stone", "res://Presentation/SourceTerrainStoneGargoyleVisual.gd"],
	147: ["skeletons_skeleton_knight", "res://Presentation/SourceTerrainOrcishMageVisual.gd"],
	80: ["frogs_frog_giant", "res://Presentation/SourceTerrainFrogVisual.gd"],
	14: ["elementals_earth_elemental", "res://Presentation/SourceTerrainEarthVisual.gd"],
	51: ["slimes_slime", "res://Presentation/SourceTerrainSlimeVisual.gd"],
	140: ["orcs_orc_shaman", "res://Presentation/SourceTerrainOrcishMageVisual.gd"],
	775: ["plague_beast", "res://Presentation/SourceTerrainPlagueBeastVisual.gd"],
	26: ["spirits_ghost", "res://Presentation/SourceTerrainWraithVisual.gd"],
	781: ["fire_ant_worker", "res://Presentation/SourceTerrainSolenWorkerVisual.gd"],
	805: ["black_ant_worker", "res://Presentation/SourceTerrainSolenWorkerVisual.gd"],
	158: ["elementals_acid_elemental", "res://Presentation/SourceTerrainAcidElementalVisual.gd"],
	162: ["elementals_poison_elemental", "res://Presentation/SourceTerrainPoisonElementalVisual.gd"],
	215: ["rodents_rat_giant", "res://Presentation/SourceTerrainGiantRatVisual.gd"],
	86: ["ophidians_ophidian_warrior", "res://Presentation/SourceTerrainOphidianVisual.gd"],
	124: ["mages_evil_mage", "res://Presentation/SourceTerrainEvilMageVisual.gd"],
	764: ["juka_warrior", "res://Presentation/SourceTerrainJukaWarriorVisual.gd"],
	12: ["dragons_dragon_blasted_slot11_12", "res://Presentation/SourceTerrainDrakeVisual.gd"],
	59: ["dragons_dragon_blasted_red_slot11_59", "res://Presentation/SourceTerrainDrakeVisual.gd"],
	40: ["daemons_daemon_elder", "res://Presentation/SourceTerrainBalronVisual.gd"],
	85: ["ophidians_ophidian_mage", "res://Presentation/SourceTerrainOphidianMageVisual.gd"],
	70: ["terathan_terathan_warrior", "res://Presentation/SourceTerrainTerathanVisual.gd"],
	71: ["terathan_terathan_drone", "res://Presentation/SourceTerrainTerathanVisual.gd"],
	154: ["walking_dead_mummy", "res://Presentation/SourceTerrainMummyVisual.gd"],
	206: ["lizards_lava_lizard", "res://Presentation/SourceTerrainLavaLizardVisual.gd"],
	76: ["titans_titan", "res://Presentation/SourceTerrainTitanVisual.gd"],
	87: ["ophidians_ophidian_queen", "res://Presentation/SourceTerrainMatriarchVisual.gd"],
	11: ["arachnids_spider_dread_slot11_11", "res://Presentation/SourceTerrainDreadSpiderVisual.gd"],
	782: ["fire_ant_warrior", "res://Presentation/SourceTerrainSolenWarriorVisual.gd"],
	806: ["black_ant_warrior", "res://Presentation/SourceTerrainSolenWarriorVisual.gd"],
	125: ["mages_evil_mage_master_actions_125", "res://Presentation/SourceTerrainEvilMageLordVisual.gd"],
	126: ["mages_evil_mage_master_actions_126", "res://Presentation/SourceTerrainEvilMageLordVisual.gd"],
	57: ["skeletons_skeleton", "res://Presentation/SourceTerrainBoneKnightVisual.gd"],
	110: ["elementals_copper_dull_elemental", "res://Presentation/SourceTerrainDullCopperVisual.gd"],
	161: ["elementals_ice_elemental", "res://Presentation/SourceTerrainIceElementalVisual.gd"],
	75: ["cyclops_cyclops", "res://Presentation/SourceTerrainCyclopsVisual.gd"],
	152: ["terathan_terathan_avenger", "res://Presentation/SourceTerrainTerathanVisual.gd"],
	778: ["gazer_larva", "res://Presentation/SourceTerrainGazerLarvaVisual.gd"],
	73: ["harpies_harpy_stone", "res://Presentation/SourceTerrainStoneHarpyVisual.gd"],
	149: ["succubi_succubus", "res://Presentation/SourceTerrainTerathanVisual.gd"],
	248: ["wild_guar", "res://Presentation/SourceTerrainGamanVisual.gd"],
	72: ["terathan_terathan_queen", "res://Presentation/SourceTerrainTerathanMatriarchVisual.gd"],
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
	var ostard := preload("res://Presentation/OstardMount.gd")
	ostard.frenzied_terrain = ResourceLoader.exists("res://local-art/ostards/frenzied-modern.gltf", "PackedScene")
	var reptalon := Registry.entry(276)
	if reptalon.get("presentation_script") == "res://Presentation/SourceReptalonActionsVisual.gd":
		Registry.entries[276] = reptalon.merged({"presentation_script": "res://Presentation/SourceLooseReptalonBreathVisual.gd"}, true)
	var enabled: Array[int] = []
	var parrot := Registry.entry(831)
	if parrot.has("enhanced_variant_falls") and checked_assets(parrot):
		Registry.entries[831] = parrot.merged({
			"presentation_script": "res://Presentation/SourceTerrainParrotVariantsVisual.gd",
		}, true)
		enabled.append(831)
	for body: int in Forms:
		var row := Registry.entry(body)
		if row.get("kind") != Forms[body][0] or not ready_for_terrain(body, row):
			continue
		var prepared := row.duplicate()
		prepared.presentation_script = Forms[body][1]
		if body == 92 and row.get("presentation_script") in [
				"res://Presentation/SourceEnhancedSilverSerpentVisual.gd",
				"res://Presentation/SourceTerrainEnhancedSilverSerpentVisual.gd"]:
			prepared.presentation_script = "res://Presentation/SourceTerrainEnhancedSilverSerpentVisual.gd"
		if body == 241 and not row.has("enhanced_source_action_groups"):
			prepared.presentation_script = "res://Presentation/SourceTerrainClassicOniVisual.gd"
		if body == 770 and not row.has("enhanced_source_action_groups"):
			prepared.presentation_script = "res://Presentation/SourceTerrainClassicMeerMageVisual.gd"
		if body == 301 and not row.has("enhanced_source_action_groups"):
			prepared.presentation_script = "res://Presentation/SourceTerrainClassicTreefellowVisual.gd"
		if body == 281 and not row.has("enhanced_source_action_groups"):
			prepared.presentation_script = "res://Presentation/SourceTerrainClassicMinotaurScoutVisual.gd"
		if body == 771 and not row.has("enhanced_source_action_groups"):
			prepared.presentation_script = "res://Presentation/SourceTerrainClassicMeerWarriorVisual.gd"
		if body == 305 and not row.has("enhanced_source_action_groups"):
			prepared.presentation_script = "res://Presentation/SourceTerrainClassicGoreFiendVisual.gd"
		if body == 263 and not row.has("enhanced_source_action_groups"):
			prepared.presentation_script = "res://Presentation/SourceTerrainClassicMinotaurVisual.gd"
		if body == 300 and not row.has("enhanced_source_action_groups"):
			prepared.presentation_script = "res://Presentation/SourceTerrainClassicCrystalElementalVisual.gd"
		if body == 243 and not row.has("enhanced_source_action_groups"):
			prepared.presentation_script = "res://Presentation/SourceTerrainClassicHiryuVisual.gd"
		if body == 168 and not row.has("enhanced_source_action_groups"):
			prepared.presentation_script = "res://Presentation/SourceTerrainClassicShadowFiendVisual.gd"
		if body == 251 and not row.has("enhanced_source_action_groups"):
			prepared.presentation_script = "res://Presentation/SourceTerrainClassicRevenantLionVisual.gd"
		if body == 303 and not row.has("enhanced_source_action_groups"):
			prepared.presentation_script = "res://Presentation/SourceTerrainClassicDevourerVisual.gd"
		if body == 790 and not row.has("enhanced_source_action_groups"):
			prepared.presentation_script = "res://Presentation/SourceTerrainClassicSandVortexVisual.gd"
		if body == 730 and not row.has("enhanced_source_action_groups"):
			prepared.presentation_script = "res://Presentation/SourceTerrainClassicRaptorVisual.gd"
		if body == 244 and not row.has("enhanced_source_action_groups"):
			prepared.presentation_script = "res://Presentation/SourceTerrainClassicRuneBeetleVisual.gd"
		if body == 157 and not row.has("enhanced_source_action_groups"):
			prepared.presentation_script = "res://Presentation/SourceTerrainClassicBlackWidowVisual.gd"
		if body == 734 and not row.has("enhanced_source_action_groups"):
			prepared.presentation_script = "res://Presentation/SourceTerrainClassicSlithVisual.gd"
		if body == 302 and not row.has("enhanced_source_action_groups"):
			prepared.presentation_script = "res://Presentation/SourceTerrainClassicHopperVisual.gd"
		if body == 245 and not row.has("enhanced_source_action_groups"):
			prepared.presentation_script = "res://Presentation/SourceTerrainClassicYomotsuWarriorVisual.gd"
		if body == 128 and not row.has("enhanced_source_action_groups"):
			prepared.presentation_script = "res://Presentation/SourceTerrainClassicPixieVisual.gd"
		if body == 265 and not row.has("enhanced_source_action_groups"):
			prepared.presentation_script = "res://Presentation/SourceTerrainClassicHydraVisual.gd"
		if body in [754, 755] and not row.has("enhanced_source_action_groups"):
			prepared.presentation_script = "res://Presentation/SourceTerrainClassicArmoredGargoyleVisual.gd"
		if body == 785 and not row.has("enhanced_source_action_groups"):
			prepared.presentation_script = "res://Presentation/SourceTerrainClassicMolochVisual.gd"
		if body == 189 and not row.has("enhanced_source_action_groups"):
			prepared.presentation_script = "res://Presentation/SourceTerrainClassicOrcBruteVisual.gd"
		if body == 130 and not row.has("enhanced_source_action_groups"):
			prepared.presentation_script = "res://Presentation/SourceTerrainClassicFireGargoyleVisual.gd"
		if body == 123 and not row.has("enhanced_source_action_groups"):
			prepared.presentation_script = "res://Presentation/SourceTerrainClassicLatticeSeekerVisual.gd"
		if body == 791 and not row.has("enhanced_source_action_groups"):
			prepared.presentation_script = "res://Presentation/SourceTerrainClassicGiantBeetleVisual.gd"
		if body in [90, 147] and not row.has("enhanced_source_action_groups"):
			apply_local_fitted_scene(prepared, body)
		if body == 14 and row.get("presentation_script") in [
				"res://Presentation/SourceEnhancedEarthVisual.gd", "res://Presentation/SourceTerrainEnhancedEarthVisual.gd"]:
			prepared.presentation_script = "res://Presentation/SourceTerrainEnhancedEarthVisual.gd"
		if body == 26 and row.has("enhanced_source_action_groups"):
			prepared.presentation_script = "res://Presentation/SourceTerrainEnhancedWraithVisual.gd"
		if body == 87 and row.has("enhanced_source_action_groups"):
			prepared.presentation_script = "res://Presentation/SourceTerrainEnhancedMatriarchVisual.gd"
		if row.has("enhanced_variant_falls"):
			prepared.presentation_script = prepared.presentation_script.trim_suffix("Visual.gd") + "VariantsVisual.gd"
		Registry.entries[body] = prepared
		enabled.append(body)
	if preload("res://Presentation/SourceSnowLeopardProfile.gd").enable():
		enabled.append(64)
		enabled.append(65)
	if enable_orc_lord():
		enabled.append(OrcLord)
	if enable_bog_clock():
		enabled.append(780)
	if enable_rabbit():
		enabled.append(RabbitBody)
	return enabled


static func apply_local_fitted_scene(row: Dictionary, body: int) -> void:
	const Fitted := preload("res://Presentation/EnhancedCreatureProfile.gd")
	var fitted: Dictionary = Fitted.read_rows(Fitted.MANIFEST, Fitted.SCENES, body).get(body, {})
	if not fitted.is_empty():
		row.assets = fitted.assets
		row.asset_sha256 = fitted.asset_sha256


static func ready_for_terrain(body: int, row: Dictionary) -> bool:
	if body == 165:
		return row.has("enhanced_source_action_groups") and checked_asset(row, "modern")
	if body == 92 and Registry.asset_path(row).begins_with("res://local-art/creatures/silver-serpent-enhanced/"):
		# The optional Silver Serpent profile validates each fitted scene before
		# replacing its base paths. The base hashes intentionally remain intact.
		return row.get("presentation_script") in [
			"res://Presentation/SourceEnhancedSilverSerpentVisual.gd",
			"res://Presentation/SourceTerrainEnhancedSilverSerpentVisual.gd"]
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



static func enable_bog_clock() -> bool:
	const Body := 780
	var row := Registry.entry(Body)
	if row.get("kind") != "bog_thing":
		return false
	var renderer: String = row.get("presentation_script", "")
	var path := Registry.asset_path(row)
	var script: String
	if renderer == "res://Presentation/BogThingActionsVisual.gd" and path == "res://local-art/creatures/bog-thing-actions.scn":
		var digest: String = row.get("authored_action_scene_sha256", {}).get("modern", "")
		if digest.length() == 64 and FileAccess.get_sha256(path) == digest:
			script = "res://Presentation/SourceTerrainBogThingVisual.gd"
	elif renderer == "res://Presentation/SourceEnhancedBogThingVisual.gd" \
			and path == "res://local-art/creatures/enhanced-creature-actions/780-modern.scn" and checked_asset(row, "modern"):
		script = "res://Presentation/SourceTerrainBogThingVisual.gd"
	if not script.is_empty():
		var prepared := row.duplicate()
		prepared.presentation_script = script
		Registry.entries[Body] = prepared
	return not script.is_empty()



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
