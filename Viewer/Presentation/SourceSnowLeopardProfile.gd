# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Renderer := "res://Presentation/SourceLivingCougarVisual.gd"
const Treatments := ["original", "rounded", "modern"]


static func enable(directory := "res://local-art/creatures/snow-leopard-prepared") -> bool:
	var base := Registry.entry(64)
	if base.get("kind") != "felines_leopard_snow" or Registry.entry(65) != base:
		return false
	var proof: Variant = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("bake-receipt.json")))
	if not proof is Dictionary:
		return false
	var paths := {}
	for style: String in Treatments:
		var source := Registry.asset_path(base, style)
		var baked := directory.path_join("snow-leopard-%s.scn" % style)
		var recorded: Dictionary = proof.get(style, {})
		var digest: String = base.asset_sha256.get(style, "")
		if digest.length() != 64 or digest != recorded.get("source") or digest != FileAccess.get_sha256(source):
			return false
		if not ResourceLoader.exists(baked, "PackedScene") or FileAccess.get_sha256(baked) != recorded.get("scene"):
			return false
		paths[style] = baked
	var prepared := base.duplicate(true)
	prepared.assets = paths
	prepared.presentation_script = Renderer
	prepared.classic_action_categories = {"5": "Attack", "6": "FelineRearSwipe", "8": "Death2",
		"9": "FelineStretch", "10": "FelineSniff", "12": "Death"}
	Registry.entries[64] = prepared
	Registry.entries[65] = prepared
	return true

