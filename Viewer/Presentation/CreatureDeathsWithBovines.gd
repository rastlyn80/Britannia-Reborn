extends "res://Presentation/CreatureDeaths.gd"
## Use the shared transition tracker for native loose cattle.

const Animals := preload("res://Presentation/AnimalVisual.gd")
const Bovine := preload("res://Presentation/BovineActionsVisual.gd")

func begin_death(killed: int, corpse: int) -> void:
	var entity: Dictionary = session.entities.get(killed, {})
	var body := int(entity.get("body", 0))
	if not Animals.BODIES.has(body):
		super.begin_death(killed, corpse)
		return
	var avatar: Node3D = scene.get("avatars").get(killed)
	if active.has(killed) or not is_instance_valid(avatar):
		return
	var source: Node3D = avatar.get("horse_visual")
	if not is_instance_valid(source):
		return
	if not source is Bovine:
		super.begin_death(killed, corpse)
		return
	var visual: Node3D = source.get_script().new()
	visual.kind = source.kind
	visual.treatment = source.treatment
	add_child(visual)
	visual.apply_identity(body, int(entity.get("hue", 0)))
	visual.set_physics_process(false)
	var duration: float = visual.begin_death_from(source)
	track_transition(killed, corpse, body, avatar, visual, duration)
