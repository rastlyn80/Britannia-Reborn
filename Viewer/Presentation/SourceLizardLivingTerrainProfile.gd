# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Base := "res://Presentation/SourceLizardActionsVisual.gd"
const Renderer := "res://Presentation/SourceLivingArmedLizardVisual.gd"
const Forms := {35: "lizardman_spear", 36: "lizardman_mace"}


static func enable() -> bool:
	var enabled := 0
	for body: int in Forms:
		var base := Registry.entry(body)
		if base.get("presentation_script") == Renderer:
			enabled += 1
			continue
		if base.get("kind") != Forms[body] or base.get("presentation_script") != Base:
			continue
		var asset := Registry.asset_path(base)
		var expected: String = base.get("asset_sha256", {}).get("modern", "")
		if expected.length() != 64 or not ResourceLoader.exists(asset, "PackedScene") \
				or FileAccess.get_sha256(asset) != expected:
			continue
		var row := base.duplicate(true)
		row["presentation_script"] = Renderer
		Registry.entries[body] = row
		enabled += 1
	return enabled == Forms.size()
