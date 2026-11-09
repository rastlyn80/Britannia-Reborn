# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-doom-creature-actions.gd"

const BindingFloor := preload("res://../scripts/CreatureMeshBindingFloor.gd")
const TRIAL := "res://local-art/creatures/doom-binding-trial/"

func run() -> void:
	Registry.load_index()
	for body: int in [311, 314]:
		var row := Registry.entry(body).duplicate(true)
		var sources := {}
		for treatment: String in ["original", "rounded", "modern"]:
			var document := GLTFDocument.new()
			var state := GLTFState.new()
			var source := TRIAL + "%s-%s.gltf" % [row.kind, treatment]
			assert(document.append_from_file(ProjectSettings.globalize_path(source), state) == OK)
			var model := document.generate_scene(state)
			root.add_child(model)
			if body == 311:
				var retained := (load(row.assets[treatment]) as PackedScene).instantiate()
				var prior := retained.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
				var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
				var motion := prior.get_animation("ShadowKnightGlance").duplicate(true) as Animation
				assert(player.get_animation_library("").add_animation("ShadowKnightGlance", motion) == OK)
				retained.free()
			BindingFloor.fit_source_floor(model)
			var packed := PackedScene.new()
			assert(packed.pack(model) == OK)
			var path := TRIAL + "bound-%d-%s.scn" % [body, treatment]
			assert(ResourceSaver.save(packed, path, ResourceSaver.FLAG_COMPRESS) == OK)
			model.free()
			sources[treatment] = path
		row.assets = sources
		Registry.entries[body] = row
		fitting_body = body
		bake_body(body, "doom-binding-trial/doom-skin-%d" % body, DOOM_CLIPS[body],
			["bake-doom-creature-actions.gd", "doom-creature-action-pins.json",
				"bake-swamp-widow-juka-actions.gd", "bake-zombie-actions.gd"])
	quit()
