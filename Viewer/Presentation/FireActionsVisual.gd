extends "res://Presentation/FireElementalVisual.gd"

const REACTION_CLIPS := ["EmberFlinch", "FlameGuard", "FlareSpread"]

func _ready() -> void:
	super._ready()
	if animator.has_animation(REACTION_CLIPS[0]):
		return
	var path: String = entry.additional_animation_library
	assert(path == "res://Art/Creatures/Fire/distinct-actions.res")
	var additional := load(path) as AnimationLibrary
	var target := animator.get_animation_library("").duplicate(true) as AnimationLibrary
	animator.remove_animation_library("")
	animator.add_animation_library("", target)
	for clip: String in REACTION_CLIPS:
		assert(target.add_animation(clip, additional.get_animation(clip).duplicate(true)) == OK)
	play(current_clip, 0.0)
