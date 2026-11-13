extends "res://Presentation/CreatureDeathsWithBovines.gd"
## Keep the special mount route and the generic death tracker in sync.

const Mounts := preload("res://Presentation/MountVisual.gd")

func begin_death(killed: int, corpse: int) -> void:
	var entity: Dictionary = session.entities.get(killed, {})
	var body := int(entity.get("body", 0))
	if Mounts.SourceOstard.selected(body, 0) and begin_source_ostard_death(killed, corpse, entity):
		return
	if (Mounts.Magical.selected(body, 0) or Mounts.DarkHorse.accepts_source(body, 0)
			or Mounts.SkeletalHorse.selected_skeletal(body, 0) or Mounts.WarHorse.selected_war_horse(body, 0)) \
			and begin_magical_death(killed, corpse, entity):
		return
	if body in [Mounts.Ostard.LlamaActions.Body, Mounts.Ostard.LlamaActions.PackBody] and begin_llama_death(killed, corpse, entity):
		return
	if body in Mounts.Horse.BODIES and begin_horse_death(killed, corpse, entity):
		return
	if body == 218 and begin_frenzied_death(killed, corpse, entity):
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



func begin_llama_death(killed: int, corpse: int, entity: Dictionary) -> bool:
	var avatar: Node3D = scene.get("avatars").get(killed)
	if active.has(killed) or not is_instance_valid(avatar):
		return false
	var source: Node3D = avatar.horse_visual
	if not source is Mounts.Ostard or source.llama_actions == null or avatar.human_visual != null:
		return false
	var body := int(entity.body)
	var visual := Mounts.create(body)
	visual.treatment = source.treatment
	add_child(visual)
	visual.apply_identity(body, int(entity.get("hue", 0)))
	visual.global_transform = source.global_transform
	visual.model.transform = source.model.transform
	visual.set_physics_process(false)
	var duration: float = visual.llama_actions.begin_death_from(visual, source)
	track_transition(killed, corpse, body, avatar, visual, duration)
	return true



func begin_source_ostard_death(killed: int, corpse: int, entity: Dictionary) -> bool:
	var avatar: Node3D = scene.get("avatars").get(killed)
	if active.has(killed) or not is_instance_valid(avatar) or not avatar.horse_visual is Mounts.SourceOstard:
		return false
	var source: Node3D = avatar.horse_visual
	var body := int(entity.body)
	var visual := Mounts.SourceOstard.create(body)
	visual.treatment = source.treatment
	add_child(visual)
	visual.apply_identity(body, int(entity.get("hue", 0)))
	visual.global_transform = source.global_transform
	visual.model.transform = source.model.transform
	visual.set_physics_process(false)
	var duration: float = visual.begin_source_death(source)
	track_transition(killed, corpse, body, avatar, visual, duration)
	return true


func begin_magical_death(killed: int, corpse: int, entity: Dictionary) -> bool:
	var avatar: Node3D = scene.get("avatars").get(killed)
	if active.has(killed) or not is_instance_valid(avatar) or not avatar.horse_visual is Mounts.Magical:
		return false
	var source: Node3D = avatar.horse_visual
	var body := int(entity.body)
	var visual := Mounts.create(body)
	add_child(visual)
	visual.apply_identity(body, int(entity.get("hue", 0)))
	visual.global_transform = source.global_transform
	visual.model.transform = source.model.transform
	visual.set_physics_process(false)
	var remaining: float = visual.begin_source_death(source)
	track_transition(killed, corpse, body, avatar, visual, remaining)
	return true


func begin_frenzied_death(killed: int, corpse: int, entity: Dictionary) -> bool:
	var avatar: Node3D = scene.get("avatars").get(killed)
	if active.has(killed) or not is_instance_valid(avatar) or not avatar.horse_visual is Mounts.Ostard:
		return false
	var source: Node3D = avatar.horse_visual
	if source.terrain == null:
		return false
	var visual := Mounts.Ostard.new()
	visual.kind = source.kind
	visual.treatment = source.treatment
	add_child(visual)
	visual.apply_identity(218, int(entity.get("hue", 0)))
	visual.set_physics_process(false)
	var duration: float = visual.terrain.begin_fall(source)
	track_transition(killed, corpse, 218, avatar, visual, duration)
	return true