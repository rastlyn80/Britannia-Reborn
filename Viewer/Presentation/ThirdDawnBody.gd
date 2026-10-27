extends Node3D
## Optional local-only body adapter. Same animate contract as Avatar.gd;
## server position, collision and the default licensed avatar stay independent.

var body := "human"
var animator: AnimationPlayer
var model: Node3D
var current_clip := "Idle"

func _ready() -> void:
	var path := "res://local-art/third-dawn/%s.gltf" % body
	if not ResourceLoader.exists(path):
		push_error("Run scripts/import-third-dawn.py with your local archive first")
		return
	model = load(path).instantiate()
	add_child(model)
	animator = model.find_children("*", "AnimationPlayer", true, false)[0]
	for clip in ["Idle", "Walk", "Run"]:
		animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	animator.play("Idle")

func animate(moving: bool, direction: float, delta: float, speed: float = 2.44) -> void:
	rotation.y = lerp_angle(rotation.y, direction, 1.0 - exp(-10.0 * delta))
	set_clip(("Run" if speed > 3.35 else "Walk") if moving else "Idle")

func set_clip(clip: String) -> void:
	if animator and (current_clip != clip or animator.current_animation != clip):
		current_clip = clip
		animator.play(clip, 0.15)

func reset_presentation() -> void:
	set_clip("Idle")
