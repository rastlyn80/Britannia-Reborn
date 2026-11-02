extends RefCounted
## Install only a profile's exact, gender-specific prepared one-shot animation.
## Profile acceptance stays outside this helper; absent/changed art stays unsupported.
const CLIP:="Savage_Dance"
static func configure(human: Node3D,profile: Dictionary) -> bool:
	var player: AnimationPlayer=human.animator
	var candidate: Variant=profile.get("tribal_dance",{})
	var wanted: Dictionary=candidate if candidate is Dictionary and profile.get("skin","")=="savage" else {}
	var asset:="res://local-art/human-npcs/savages/dance/"+("female" if human.female else "male")+"-tribal-dance.res"
	var digest:=str(wanted.get("sha256",""))
	var valid:=not wanted.is_empty() and str(wanted.get("asset",""))==asset and digest.length()==64
	valid=valid and FileAccess.file_exists(asset) and FileAccess.get_sha256(asset)==digest
	var key:=digest if valid else ""
	if str(human.get_meta("native_dance_sha256",""))==key:
		return valid
	var library: AnimationLibrary=player.get_animation_library("").duplicate()
	if library.has_animation(CLIP):library.remove_animation(CLIP)
	if valid:
		var animation:=ResourceLoader.load(asset,"Animation",ResourceLoader.CACHE_MODE_IGNORE) as Animation
		valid=animation!=null and animation.loop_mode==Animation.LOOP_NONE and animation.get_track_count()==human.skeleton.get_bone_count()*2
		valid=valid and FileAccess.get_sha256(asset)==digest
		if valid:library.add_animation(CLIP,animation)
		else:key=""
	# current_animation is empty while paused; assigned_animation retains its clip.
	var previous:=player.assigned_animation
	var time:=player.current_animation_position if not previous.is_empty() else 0.
	var playing:=player.is_playing()
	var rate:=player.get_playing_speed()/player.speed_scale if playing and absf(player.speed_scale)>.000001 else 1.
	if not playing and str(human.action_clip)==previous and not previous.is_empty():
		rate=float(human.action_rate)*(-1. if human.action_reverse else 1.)
	if previous==CLIP:
		human.cancel_action();previous=human.stance_clip("Idle");time=0.;rate=1.
	player.stop(true)
	player.remove_animation_library("");player.add_animation_library("",library)
	if not previous.is_empty() and player.has_animation(previous):
		player.play(previous,0.,rate);player.seek(time,true)
		if not playing:player.pause()
	human.set_meta("native_dance_sha256",key)
	return valid
