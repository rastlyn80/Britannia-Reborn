extends "res://Network/BovineLiveTransition.gd"

const OstardDeaths := preload("res://Presentation/CreatureDeathsWithOstard.gd")

func configure(session: Node, serial: int, actor: Node3D) -> void:
	avatars[serial] = actor
	items = Items.new()
	add_child(items)
	items.add_child(items.hint)
	items.session = session
	deaths = OstardDeaths.new()
	add_child(deaths)
	deaths.configure(self, session, items)
	deaths.transition_started.connect(func(killed: int, corpse: int, visual: Node3D):
		events[killed] = {"corpse":corpse, "clip":visual.current_clip})
