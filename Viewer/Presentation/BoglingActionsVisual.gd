extends "res://Presentation/BoglingVisual.gd"

const ADDED_GESTURES := ["RootGuard", "Uncurl"]
const PUBLIC_LIBRARY := "res://Art/Creatures/Bogling/distinct-actions.res"
const CANDIDATE_LIBRARY := "res://local-art/creatures/bogling-distinct-actions.res"

func _ready() -> void:
	super._ready()
	var path: String = entry.additional_animation_library
	assert(path == PUBLIC_LIBRARY or path == CANDIDATE_LIBRARY)
	var added := load(path) as AnimationLibrary
	var library := animator.get_animation_library("").duplicate() as AnimationLibrary
	animator.remove_animation_library("")
	animator.add_animation_library("", library)
	for clip: String in ADDED_GESTURES:
		assert(library.add_animation(clip, added.get_animation(clip).duplicate(true)) == OK)
	play(current_clip, 0.0)

