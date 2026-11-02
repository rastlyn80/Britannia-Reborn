extends Node3D
## Native death packets start a temporary visual; server entities/items stay authoritative.
const Creatures=preload("res://Presentation/CreatureRegistry.gd")
signal transition_started(killed: int,corpse: int,visual: Node3D)
var scene: Node3D
var session: Node
var items: Node
var active: Dictionary={}
var held_corpses: Dictionary={}
func configure(owner_scene: Node3D,connection: Node,item_presenter: Node) -> void:
	scene=owner_scene;session=connection;items=item_presenter
	session.module("player").death_animation.connect(begin_death)
	session.world_item_changed.connect(func(serial: int,_item: Dictionary):_update_corpse(serial))
	session.ended.connect(clear)
func begin_death(killed: int,corpse: int) -> void:
	if active.has(killed) or not session.entities.has(killed):return
	var entity: Dictionary=session.entities[killed];var body:=int(entity.get("body",0))
	var avatars: Dictionary=scene.get("avatars")
	if not Creatures.supports_body(body) or not avatars.has(killed):return
	var avatar: Node3D=avatars[killed];var source: Node3D=avatar.get("horse_visual")
	if not is_instance_valid(source):return
	var visual:=Creatures.create(body);add_child(visual);visual.apply_identity(body,int(entity.get("hue",0)))
	# Snapshot equipment before later corpse/loot packets change the mobile.
	if visual.has_method("set_equipment"):
		visual.set_equipment(avatar.get_meta("server_appearance",{}).get("equipment",[]))
	visual.global_transform=source.global_transform
	visual.rotation.y=PI-float(int(entity.get("direction",0))&7)*PI/4.
	visual.model.transform=source.model.transform
	visual.set_physics_process(false);visual.contact.enabled=false
	var duration: float=visual.animator.get_animation("Death").length
	visual.current_clip="Death";visual.dead=true;visual.action_remaining=duration;visual.play("Death",.08)
	visual.set_meta("native_death",{"killed":killed,"corpse":corpse,"body":body})
	active[killed]={"visual":visual,"avatar":weakref(avatar),"was_visible":avatar.visible,"remaining":duration+.04,"corpse":corpse}
	avatar.visible=false
	if corpse!=0:held_corpses[corpse]=killed;_update_corpse(corpse)
	transition_started.emit(killed,corpse,visual)
func _update_corpse(serial: int) -> void:
	if not held_corpses.has(serial):return
	var nodes: Dictionary=items.get("nodes")
	if nodes.has(serial):nodes[serial].visible=false
func _process(delta: float) -> void:
	for killed in active.keys():
		active[killed].remaining-=delta
		if active[killed].remaining<=0.:finish(int(killed))
func finish(killed: int) -> void:
	if not active.has(killed):return
	var state: Dictionary=active[killed];active.erase(killed)
	var avatar: Node3D=state.avatar.get_ref()
	var avatars: Dictionary=scene.get("avatars")
	if is_instance_valid(avatar) and avatars.get(killed)==avatar:avatar.visible=state.was_visible
	var corpse:=int(state.corpse)
	if held_corpses.get(corpse)==killed:
		held_corpses.erase(corpse)
		var nodes: Dictionary=items.get("nodes")
		if nodes.has(corpse):nodes[corpse].visible=true
	if is_instance_valid(state.visual):state.visual.queue_free()
func clear() -> void:
	for killed in active.keys():finish(int(killed))
