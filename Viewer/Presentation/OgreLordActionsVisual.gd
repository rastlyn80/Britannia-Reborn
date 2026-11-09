extends "res://Presentation/SourceQuadrupedCollapseVisual.gd"

const GestureSupport := preload("res://Presentation/CreatureGesturePlaneSupport.gd")
const Variants := preload("res://Presentation/CreatureModeZeroVariants.gd")
const GROUNDED_CLIPS: Array[String] = ["OverheadHammer", "HighUppercut", "FaceWipe", "ShoulderTurn", "ChestBrace", "ShoulderScratch"]
var gesture := GestureSupport.new()

func _ready() -> void:
	super._ready()
	gesture.bind_actor(self, GROUNDED_CLIPS)

func receive_action(request: Dictionary) -> bool:
	gesture.restore(self)
	var base := entry
	entry = Variants.entry_for_packet(entry, request)
	var handled := super.receive_action(request)
	entry = base
	return handled

func _physics_process(delta: float) -> void:
	gesture.restore(self)
	super._physics_process(delta)

func begin_death_from(source: Node3D) -> float:
	if not source.dead or source.current_clip != "Death2":
		return super.begin_death_from(source)
	# CreatureDeaths copies the source model before creating this transition.
	# Remove its display-only lift, then settle the same alternate fall phase.
	model.position -= source.collapse_shift
	collapse_plane = source.collapse_plane.duplicate()
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	collapse_skin = Ground.skin_points(mesh, skeleton)
	var time: float = source.animator.current_animation_position
	var speed := maxf(0.01, source.animator.get_playing_speed())
	current_clip = "Death2"
	dead = true
	animator.play(current_clip, 0.0, speed)
	animator.advance(0.0)
	animator.seek(time, true)
	action_remaining = maxf(0.0, animator.current_animation_length - time) / speed
	return action_remaining
