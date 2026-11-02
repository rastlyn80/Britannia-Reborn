extends "res://Presentation/FootContact.gd"
## Gated NPC support after normal leg IK. Never alter the network-controlled root.
## Only a common supporting plane is handled here; split treads stay explicit.
const Ground=preload("res://Presentation/SourceGroundLookup.gd")
var full_skin: Dictionary={}
var correction_m:=0.
var source_human: WeakRef
static func sync_avatar(avatar: Node3D,profile: Dictionary) -> bool:
	var enabled: bool=profile.get("skin","")=="savage" and int(profile.get("body",0)) in [183,184,185,186]
	var desired: Script=load("res://Presentation/HumanNPCFootContact.gd" if enabled else "res://Presentation/FootContact.gd")
	var contact: SkeletonModifier3D=avatar.foot_contact
	if contact.get_script()!=desired:
		var state: Dictionary={}
		for key in ["grounded","root_height","contacts","weights","body_offset"]:state[key]=contact.get(key)
		contact.set_script(desired)
		for key: String in state:contact.set(key,state[key])
	if not enabled:
		if contact.has_meta("native_complete_skin_support"):contact.remove_meta("native_complete_skin_support")
		contact.active=true
		return true
	var mesh: MeshInstance3D=avatar.human_visual.model.find_children("Body*","MeshInstance3D",true,false)[0]
	var supported: bool=contact.call("configure_body",mesh)
	contact.set("source_human",weakref(avatar.human_visual))
	contact.set_meta("native_complete_skin_support",supported)
	contact.active=supported or str(avatar.human_visual.action_clip)!="Savage_Dance"
	return supported
func configure_body(mesh: MeshInstance3D) -> bool:
	full_skin={}
	var rig:=get_skeleton()
	if rig==null:return false
	var candidate:=Ground.skin_points(mesh,rig)
	var pelvis:=rig.find_bone("pelvis")
	if pelvis<0:return false
	# A pelvis translation must move every weighted body point by the same amount.
	for surface: Dictionary in candidate.surfaces:
		for offset in surface.weights.size():
			if float(surface.weights[offset])<=0.:continue
			var bone:=int(candidate.bones[int(surface.bindings[offset])])
			while bone>=0 and bone!=pelvis:bone=rig.get_bone_parent(bone)
			if bone!=pelvis:return false
	full_skin=candidate
	return true
func leg_ik_enabled() -> bool:
	var human: Node3D=source_human.get_ref() if source_human!=null else null
	return human==null or str(human.action_clip)!="Savage_Dance"
func dance_clearance() -> float:
	var human: Node3D=source_human.get_ref() if source_human!=null else null
	if human==null or str(human.action_clip)!="Savage_Dance":return 0.
	var player: AnimationPlayer=human.animator
	if player.assigned_animation!="Savage_Dance":return 0.
	var clip:=player.get_animation("Savage_Dance")
	var curve: PackedVector2Array=clip.get_meta("npc_full_body_clearance",PackedVector2Array())
	if curve.size()<2:return 0.
	var time:=player.current_animation_position;var left:=0;var right:=curve.size()-1
	while right-left>1:
		var mid: int=(left+right)/2
		if curve[mid].x<=time:left=mid
		else:right=mid
	return lerpf(curve[left].y,curve[right].y,clampf((time-curve[left].x)/maxf(.000001,curve[right].x-curve[left].x),0.,1.))
func _process_modification_with_delta(delta: float) -> void:
	var standing:=leg_ik_enabled()
	if standing:super._process_modification_with_delta(delta)
	correction_m=0.
	if has_meta("unsupported_support_gap_m"):remove_meta("unsupported_support_gap_m")
	if not grounded or full_skin.is_empty() or not contacts.has("l") or not contacts.has("r"):return
	var left: Dictionary=contacts.l;var right: Dictionary=contacts.r
	var normal: Vector3=left.normal;var origin: Vector3=left.position
	if normal.y<.75 or normal.dot(right.normal)<.999 or absf(normal.dot((right.position as Vector3)-origin))>.004:return
	var rig:=get_skeleton();rig.force_update_all_bone_transforms()
	var minimum:=Ground.minimum_plane_gap(full_skin,rig,rig.global_transform,origin,normal)
	var wanted:=0. if standing else dance_clearance()
	if standing and minimum>=0.:
		var human: Node3D=source_human.get_ref() if source_human!=null else null
		# Idle should settle onto its sole; a gait/action's positive rise is authored.
		if human!=null and (not str(human.action_clip).is_empty() or preload("res://Presentation/HumanActions.gd").locomotion(str(human.current_clip))):return
	var shift:=(wanted-minimum)/normal.y
	# Large corrections indicate a different unsupported pose, not a sole error.
	if absf(shift)>(.03 if standing else .2):
		set_meta("unsupported_support_gap_m",minimum);return
	var pelvis:=rig.find_bone("pelvis");var pose:=rig.get_bone_global_pose(pelvis)
	pose.origin+=rig.global_basis.inverse()*Vector3.UP*shift
	rig.set_bone_global_pose(pelvis,pose);correction_m=shift
