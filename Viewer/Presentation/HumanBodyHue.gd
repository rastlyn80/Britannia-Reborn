# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Hue := preload("res://Presentation/HumanHue.gd")


static func apply(skin: ShaderMaterial, hue: int, treatment: String, exact_body_hue: bool) -> void:
	var index := hue & 0x3fff
	var palette: Texture2D
	var full_dye := exact_body_hue and treatment.is_empty() and (hue & 0x8000) == 0
	var natural_skin := index >= 1002 and index <= 1058
	# Preserve the authored presets for natural skin and apply the full palette
	# to custom NPC body dyes, including the Forgotten Servant.
	if treatment == "vampiric" or (full_dye and index > 0 and not natural_skin):
		palette = Hue.palette(hue)
	skin.set_shader_parameter("form_hue_palette", palette)
	skin.set_shader_parameter("use_form_hue", palette != null)
