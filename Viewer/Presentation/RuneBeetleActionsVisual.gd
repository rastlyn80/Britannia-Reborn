extends "res://Presentation/RuneBeetleVisual.gd"

const GestureSupport := preload("res://Presentation/CreatureGesturePlaneSupport.gd")
const Variants := preload("res://Presentation/CreatureModeZeroVariants.gd")
const GROUNDED_CLIPS: Array[String] = ["RuneCrestProbe", "BlockLeft", "BlockRight"]
var gesture := GestureSupport.new()

func _ready() -> void:
	super._ready()
	gesture.bind_actor(self, GROUNDED_CLIPS)

func receive_action(request: Dictionary) -> bool:
	gesture.restore(self)
	var base := entry
	if int(request.get("type", -1)) == 0:
		entry = Variants.entry_for_packet(entry, request)
	var handled := super.receive_action(request)
	entry = base
	return handled

func _physics_process(delta: float) -> void:
	gesture.restore(self)
	super._physics_process(delta)
