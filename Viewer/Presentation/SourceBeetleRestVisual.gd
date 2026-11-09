extends "res://Presentation/SourceBeetleVisual.gd"
## Hold the fitted resting pose with the ordinary animal action lifecycle.

func _ready() -> void:
	super._ready()
	var clips := animator.get_animation_library("")
	assert(clips.has_animation("BeetleRest"))
	clips.remove_animation("LieDown")
	clips.rename_animation("BeetleRest", "LieDown")

func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if current_clip == "LieDown":
		# Plane support keeps the resting shell clear on slopes.
		contact.enabled = true
	return true
