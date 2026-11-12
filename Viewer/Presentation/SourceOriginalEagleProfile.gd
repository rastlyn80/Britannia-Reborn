# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Folder := "res://local-art/creatures/original-eagle/"
const Renderer := "res://Presentation/SourceOriginalEagleVisual.gd"
const Body := 5
const Inputs := "ced1ecf4dc11eb25abe050a196f7114d70210e8001caf8d171668d06d760bfde"


static func enable() -> bool:
	var original := Registry.entry(Body)
	if original.get("kind") != "eagle" or not FileAccess.file_exists(Folder + "manifest.json"):
		return false
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(Folder + "manifest.json"))
	if not manifest is Dictionary or manifest.get("schema") != 1 or manifest.get("input_sha256") != Inputs:
		return false
	var assets := {}
	var hashes := {}
	for treatment: String in ["original", "rounded", "modern"]:
		var asset := Folder + "5-%s.scn" % treatment
		var digest: String = manifest.get("variants", {}).get(treatment, "")
		if digest.length() != 64 or not ResourceLoader.exists(asset, "PackedScene") or FileAccess.get_sha256(asset) != digest:
			return false
		assets[treatment] = asset
		hashes[treatment] = digest
	var row := original.duplicate(true)
	row.assets = assets
	row.asset_sha256 = hashes
	row.presentation_script = Renderer
	row.surface_kind = "source_eagle_feathers"
	row.head_bone = "bip01 head"
	Registry.entries[Body] = row
	return true
