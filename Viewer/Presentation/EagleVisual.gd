extends "res://Presentation/CreatureVisual.gd"
## Explicit presentation flight, never an invented authoritative server flag.
## current_clip remains the native replacement category; assigned_animation
## and rendered_action_clip record the actual airborne/landing clip.
var flight_state:="ground"
var transition_remaining:=0.
var wanted_moving:=false
var wanted_speed:=0.
var pending_ground_clip:=""
var pending_ground_duration:=0.
func set_hue(value: int) -> void:
	super.set_hue(value)
	if model==null or treatment!="modern":return
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var source:=mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if source!=null:mesh.set_surface_override_material(surface,preload("res://Presentation/CreatureEagleMaterial.gd").build(source,value))
func begin_transition(take_off: bool) -> void:
	flight_state="taking_off" if take_off else "landing"
	current_clip="TakeOff" if take_off else "Land"
	transition_remaining=animator.get_animation(current_clip).length
	animator.speed_scale=1.;animator.play(current_clip,.12);contact.enabled=true
	set_meta("rendered_action_clip",current_clip)
func play_gait(moving: bool,speed: float) -> void:
	wanted_moving=moving;wanted_speed=speed
	if dead or action_remaining>0. or transition_remaining>0.:return
	if moving and flight_state=="ground":begin_transition(true);return
	if not moving and flight_state=="air":begin_transition(false);return
	super.play_gait(moving,speed)
func _process(delta: float) -> void:
	super._process(delta)
	if dead:transition_remaining=0.;pending_ground_clip="";return
	if transition_remaining<=0.:return
	transition_remaining=maxf(0.,transition_remaining-delta)
	if transition_remaining>0.:return
	if flight_state=="landing_action":
		flight_state="ground";animator.speed_scale=1.
		animator.play(pending_ground_clip,.12,animator.get_animation(pending_ground_clip).length/maxf(.01,pending_ground_duration))
		set_meta("rendered_action_clip",pending_ground_clip);pending_ground_clip="";return
	flight_state="air" if flight_state=="taking_off" else "ground"
	if flight_state=="air" and not wanted_moving:begin_transition(false);return
	if flight_state=="ground" and wanted_moving:begin_transition(true);return
	super.play_gait(wanted_moving,wanted_speed)
func receive_action(request: Dictionary) -> bool:
	var airborne:=flight_state!="ground"
	if not super.receive_action(request):return false
	transition_remaining=0.;pending_ground_clip="";animator.speed_scale=1.
	if airborne and animator.has_animation("Air"+current_clip):
		var clip:="Air"+current_clip
		flight_state="air"
		animator.play(clip,.12,animator.get_animation(clip).length/maxf(.01,action_remaining))
		set_meta("rendered_action_clip",clip)
		return true
	if airborne and current_clip in ["Eat","Fidget","Alert","LieDown"]:
		pending_ground_clip=current_clip;pending_ground_duration=action_remaining
		flight_state="landing_action";transition_remaining=animator.get_animation("Land").length
		action_remaining+=transition_remaining;animator.play("Land",.12);set_meta("rendered_action_clip","Land")
		return true
	flight_state="ground";set_meta("rendered_action_clip",current_clip);return true
