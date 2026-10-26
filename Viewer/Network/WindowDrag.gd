extends Control
var target: Control
var dragging := false
func _gui_input(event: InputEvent) -> void:
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
  dragging = event.pressed
  accept_event()
 elif event is InputEventMouseMotion and dragging:
  var area := get_viewport_rect().size
  target.position = (target.position+event.relative).clamp(Vector2(-position.x,-position.y),area-Vector2(80,40)-position)
  accept_event()
func _notification(what: int) -> void:
 if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT: dragging = false
