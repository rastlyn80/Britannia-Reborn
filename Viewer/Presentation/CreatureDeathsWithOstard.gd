extends "res://Presentation/CreatureDeathsWithBovines.gd"
## Keep the special mount route and the generic death tracker in sync.

const Mounts := preload("res://Presentation/MountVisual.gd")

func begin_death(killed: int, corpse: int) -> void:
	var entity: Dictionary = session.entities.get(killed, {})
	if int(entity.get("body", 0)) != 210:
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
