extends "res://Presentation/CreatureDeathsWithBovines.gd"
## Keep the special mount route and the generic death tracker in sync.

const Mounts := preload("res://Presentation/MountVisual.gd")

func begin_death(killed: int, corpse: int) -> void:
	var entity: Dictionary = session.entities.get(killed, {})
	var body := int(entity.get("body", 0))
	if body in Mounts.Horse.BODIES and begin_horse_death(killed, corpse, entity):
		return
	if body != 210:
		super.begin_death(killed, corpse)
		return
	var avatar: Node3D = scene.get("avatars").get(killed)
	if active.has(killed) or not is_instance_valid(avatar):
		return
	var source: Node3D = avatar.get("horse_visual")
	if not is_instance_valid(source) or source.get("desert_actions") == null:
		super.begin_death(killed, corpse)
		return
	var visual := Mounts.create(210)
	visual.treatment = source.treatment
	add_child(visual)
	visual.apply_identity(210, int(entity.get("hue", 0)))
	visual.global_transform = source.global_transform
	visual.model.transform = source.model.transform
	visual.set_physics_process(false)
	var duration: float = visual.desert_actions.begin_death_from(visual, source)
	track_transition(killed, corpse, 210, avatar, visual, duration)


func begin_horse_death(killed: int, corpse: int, entity: Dictionary) -> bool:
	var avatar: Node3D = scene.get("avatars").get(killed)
	if active.has(killed) or not is_instance_valid(avatar):
		return false
	var source: Node3D = avatar.horse_visual
	if not source is Mounts.Horse or not source.fitted_enabled() or avatar.human_visual != null:
		return false
	var body := int(entity.body)
	var visual := Mounts.Horse.new()
	add_child(visual)
	visual.apply_identity(body, int(entity.get("hue", 0)))
	visual.set_physics_process(false)
	var duration := visual.begin_native_fall(source)
	track_transition(killed, corpse, body, avatar, visual, duration)
	return true
