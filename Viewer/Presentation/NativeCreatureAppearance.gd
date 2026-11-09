extends RefCounted
## Preserve the authoritative mobile flags alongside its normal appearance.

static func apply(avatar: Node3D, entity: Dictionary, worn: Array, profile: Dictionary) -> void:
	avatar.apply_server_appearance(entity, worn, profile)
	var creature: Node3D = avatar.horse_visual
	if (entity.has("flags") and avatar.human_visual == null and is_instance_valid(creature)
			and creature.has_method("set_native_combat_flags")):
		creature.set_native_combat_flags(int(entity.flags))
