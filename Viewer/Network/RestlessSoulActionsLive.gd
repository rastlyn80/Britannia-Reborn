extends "res://Network/KhaldunActionsLive.gd"
## Exercise the staged on-foot motion against the same isolated native fixture.

func _initialize() -> void:
	family = "restless_soul_actions"
	prepared = true
	create_timer(180.0).timeout.connect(func(): quit(2))
	call_deferred("run")
