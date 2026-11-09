# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-centaur-through-essence-actions.gd"

const BindingFloor := preload("res://../scripts/CreatureMeshBindingFloor.gd")
const TRIAL := "res://local-art/creatures/centaur-binding-trial/"

func run() -> void:
	Registry.load_index()
	var row := Registry.entry(101).duplicate(true)
	var sources := {}
	for treatment: String in ["original", "rounded", "modern"]:
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var source := TRIAL + "centaurs_centaur-" + treatment + ".gltf"
		assert(document.append_from_file(ProjectSettings.globalize_path(source), state) == OK)
		var model := document.generate_scene(state)
		root.add_child(model)
		BindingFloor.fit_source_floor(model)
		var packed := PackedScene.new()
		assert(packed.pack(model) == OK)
		var path := TRIAL + "bound-" + treatment + ".scn"
		assert(ResourceSaver.save(packed, path, ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		sources[treatment] = path
	row.assets = sources
	Registry.entries[101] = row
	fitting_body = 101
	bake_body(101, "centaur-binding-trial/centaur-skin", RARE_FITS[101],
		["bake-centaur-through-essence-actions.gd", "centaur-through-essence-action-pins.json",
			"bake-banshee-through-queens-actions.gd", "bake-swamp-widow-juka-actions.gd", "bake-zombie-actions.gd"])
	quit()

func fit_troll(player: AnimationPlayer, rig: Skeleton3D, skins: Array[Dictionary], slot: int) -> Animation:
	var joints := ["bip01 spine1", "bip01 neck1", "bip01 head", "bip01 ponytail11", "bip01 ponytail21"]
	return fit_grounded(player, rig, skins, 0.47, "bip01", joints, pose_rare_form.bind(slot), 0.009)

func pose_rare_form(rig: Skeleton3D, phase: float, _slot: int) -> void:
	var effort := pulse(phase)
	rotate(rig, "spine1", Vector3.FORWARD, -0.28 * effort)
	rotate(rig, "neck1", Vector3.UP, 0.38 * effort)
	rotate(rig, "head", Vector3.UP, 0.28 * effort)
	rotate(rig, "ponytail11", Vector3.RIGHT, -0.74 * effort)
	rotate(rig, "ponytail21", Vector3.FORWARD, -0.24 * effort)
