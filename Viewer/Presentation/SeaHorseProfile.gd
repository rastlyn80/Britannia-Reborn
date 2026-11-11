# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const ART := "res://local-art/mounts/sea-horse.scn"
const MANIFEST := "res://local-art/mounts/sea-horse.json"
const RENDERER := "res://Presentation/SeaHorseVisual.gd"
const BODY := 144
const MOUNT := 0x3eb3


static func enable() -> bool:
	Registry.load_index()
	var existing := Registry.entry(BODY)
	if not existing.is_empty():
		return existing.get("presentation_script") == RENDERER
	if not FileAccess.file_exists(MANIFEST):
		return false
	var record: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not record is Dictionary or int(record.get("schema", 0)) != 1:
		return false
	var digest: String = record.get("scene_sha256", "")
	if digest.length() != 64 or FileAccess.get_sha256(ART) != digest or not ResourceLoader.exists(ART):
		return false
	Registry.entries[BODY] = {
		"kind": "sea_horse_reconstruction", "presentation_script": RENDERER, "mount_item": MOUNT,
		"assets": {"original": ART, "rounded": ART, "modern": ART}, "profile": "monster",
		"surface_kind": "marine_pbr", "limb_support": "plane", "movement_mode": "ground_plane",
		"bodies": [{"body": BODY, "name": "Sea Horse", "scale": [1.0, 1.0, 1.0]}],
	}
	return true
