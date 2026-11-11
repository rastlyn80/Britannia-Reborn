# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Body := 218
const MountItem := 0x3ea4
const Treatments := ["original", "rounded", "modern"]
const Renderer := "res://Presentation/SourceEnhancedFrenziedOstardVisual.gd"


static func retained_row() -> Dictionary:
	var assets := {}
	for treatment: String in Treatments:
		assets[treatment] = "res://local-art/ostards/frenzied-%s.gltf" % treatment
	return {
		"kind": "frenzied", "family": "ostards", "profile": "animal", "limb_support": "plane",
		"assets": assets, "mount_item": MountItem,
		"bodies": [{"body": Body, "scale": [1.0, 1.0, 1.0], "native_profile": "animal",
			"native_class": "FrenziedOstard", "name": "Frenzied Ostard"}],
		"classic_action_categories": {"6": "Attack"},
	}
