extends Node3D
## Keep the native session decoder and corpse renderer in the same test arena.

const Deaths := preload("res://Presentation/CreatureDeathsWithBovines.gd")
const Items := preload("res://Presentation/WorldItems.gd")

var avatars: Dictionary = {}
var items: Node3D
var deaths: Node3D
var events: Dictionary = {}

func configure(session: Node, serial: int, actor: Node3D) -> void:
	avatars[serial] = actor
	items = Items.new()
	add_child(items)
	items.add_child(items.hint)
	items.session = session
	deaths = Deaths.new()
	add_child(deaths)
	deaths.configure(self, session, items)
	deaths.transition_started.connect(func(killed: int, corpse: int, visual: Node3D) -> void:
		events[killed] = {"corpse": corpse, "body": visual.native_body, "hue": visual.native_hue,
			"clip": visual.current_clip, "position": visual.animator.current_animation_position})

func place_corpse(serial: int, item: Dictionary) -> bool:
	var holder := Node3D.new()
	items.add_child(holder)
	items.nodes[serial] = holder
	if not items._equine_corpse(holder, item, serial):
		return false
	deaths._update_corpse(serial)
	return true

func settled(serial: int) -> bool:
	return items.corpse_snapshots.has(serial) and items.nodes[serial].visible

func verify_corpse(serial: int, body: int, hue: int, clip: String) -> bool:
	var corpse: Node3D = items.nodes[serial].get_node("CorpseVisual")
	return (corpse.get_meta("corpse_body") == body and corpse.get_meta("native_hue") == hue
		and corpse.get_meta("death_clip") == clip and corpse.get_meta("static_cadaver")
		and corpse.find_children("*", "Skeleton3D", true, false).is_empty())
