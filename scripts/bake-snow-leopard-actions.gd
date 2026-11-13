# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-field-fauna.gd"


func run() -> void:
	var row := Registry.entry(64)
	assert(row.kind == "felines_leopard_snow" and Registry.entry(65) == row)
	var folder := "res://local-art/creatures/snow-leopard-prepared"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			folder = argument.trim_prefix("--output=")
	assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder)) == OK)
	var scenes := {}
	for style: String in ["original", "rounded", "modern"]:
		var source := Registry.asset_path(row, style)
		var digest := FileAccess.get_sha256(source)
		assert(digest == row.asset_sha256[style])
		var output := folder.path_join("snow-leopard-%s.scn" % style)
		bake_fauna(64, source, output)
		scenes[style] = {"source": digest, "scene": FileAccess.get_sha256(output)}
	var receipt := FileAccess.open(folder.path_join("bake-receipt.json"), FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify(scenes, "  "))
	receipt.close()
	print("SNOW LEOPARD BAKE: original, rounded and modern skins on the retained 32-bone rig")
	quit()
