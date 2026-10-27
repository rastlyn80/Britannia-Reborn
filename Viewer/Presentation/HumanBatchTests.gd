extends SceneTree
const Wire = preload("res://Network/LoginProtocol.gd")
const Game = preload("res://Network/GameSession.gd")
const Look = preload("res://Network/MobileAppearance.gd")
const Wardrobe = preload("res://Presentation/HumanWardrobe.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks+=1
	if ok: print("PASS ",label)
	else:
		failures+=1
		push_error(label)
func snapshot(body: int, ids: Array) -> PackedByteArray:
	var p:=PackedByteArray([0x78,0,0])
	p.append_array(Wire.uint_be(7,4))
	p.append_array(Wire.uint_be(body,2))
	p.append_array(PackedByteArray([6,66,6,55,20,2,3,234,0,1]))
	for i in ids.size():
		p.append_array(Wire.uint_be(0x40000010+i,4))
		p.append_array(Wire.uint_be(ids[i],2))
		p.append(5+i)
		p.append_array(Wire.uint_be(0,2))
	p.append_array(Wire.uint_be(0,4))
	p[1]=p.size()>>8
	p[2]=p.size()&255
	return p
func _initialize() -> void: call_deferred("run")
func run() -> void:
	check(Game.creation_packet("Woman",0,0,true)[70]==3 and Game.creation_packet("Man",0,0,false)[70]==2,"native human creation sex byte")
	var packet:=snapshot(0x191,[0x1fa1,0x1539])
	var decoded:=Look.snapshot(packet)
	check(decoded.entity.body==0x191 and decoded.entity.hue==1002 and decoded.worn.size()==2,"native female body, skin hue and full equipment snapshot")
	var all_rejected:=true
	for length in packet.size():
		if not Look.snapshot(packet.slice(0,length)).is_empty(): all_rejected=false
	check(all_rejected,"all truncated appearance payloads rejected")
	var game:=Game.new()
	root.add_child(game)
	game.set_process(false)
	game.player.serial=7
	game.feed(packet)
	check(game.mobile_equipment[7].size()==2 and game.equipment.size()==2,"own native equipment populates both appearance and inventory")
	game.feed(snapshot(0x190,[0x1f03]))
	check(game.mobile_equipment[7].size()==1 and game.equipment.size()==1 and game.player.body==0x190,"complete appearance replaces stale layers")
	var equip:=PackedByteArray([0x2e])
	equip.append_array(Wire.uint_be(0x40000099,4))
	equip.append_array(PackedByteArray([0x17,0x0b,0,3]))
	equip.append_array(Wire.uint_be(9,4))
	equip.append_array(Wire.uint_be(0,2))
	game.feed(equip)
	check(game.mobile_equipment[9][3].id==0x170b,"remote worn update retained")
	game.remember_item({"serial":0x40000099,"id":0x170b,"container":123})
	check(game.mobile_equipment[9].is_empty(),"moving worn item to container clears its appearance")
	game.feed(equip)
	game.feed(PackedByteArray([0x1d,0x40,0,0,0x99]))
	check(game.mobile_equipment[9].is_empty(),"native removal clears worn appearance")
	check(Wardrobe.resolve([{"id":0x1fa1},{"id":0x1539},{"id":0x170b}]).bits==7 and Wardrobe.resolve([{"id":0x2687}]).bits==24,"first wardrobe resolves separable clothes and robe with hood")
	check(Wardrobe.resolve([{"id":0x1fa1},{"id":0x1f03}]).bits==8,"outer robe hides overlapping shirt")
	check(Wardrobe.resolve([{"id":0x999,"layer":5}]).unsupported==[0x999],"unmapped equipment remains explicit")
	game.free()
	var stage:=Node3D.new()
	root.add_child(stage)
	for female in [false,true]:
		var actor:=preload("res://Presentation/Avatar.gd").new()
		actor.initial_body=0x191 if female else 0x190
		stage.add_child(actor)
		actor.set_physics_process(false)
		check(actor.human_visual!=null and actor.human_visual.skeleton.get_bone_count()==61,"live %s avatar uses native human skeleton" % ("female" if female else "male"))
		var human: Node3D=actor.human_visual
		var rig: Skeleton3D=human.skeleton
		var animator: AnimationPlayer=human.animator
		actor.animate(true,0.,.1,2.4)
		animator.seek(.2,true)
		animator.pause()
		var valid:=true
		var ids:=[0x1fa1,0x1539,0x170b,0x1f03,0x278f]
		for bits in 32:
			var items: Array=[]
			for i in 5:
				if bits&(1<<i): items.append({"id":ids[i],"layer":5+i,"hue":0})
			human.set_equipment(items)
			valid=valid and human.skeleton==rig and human.animator==animator and is_equal_approx(animator.current_animation_position,.2)
			for mesh: MeshInstance3D in human.parts:
				valid=valid and mesh.get_node(mesh.skeleton)==rig
				for bind in mesh.skin.get_bind_count(): valid=valid and rig.find_bone(mesh.skin.get_bind_name(bind))>=0
			await process_frame
		check(valid,"all 32 combinations preserve animator, gait phase and compatible skin bindings")
		var finite:=true
		for clip in ["Idle","Walk","Run","Jump_Start","Jump","Jump_Land"]:
			human.play(clip,0.)
			for phase in [0.,.25,.5,.75]:
				animator.seek(animator.current_animation_length*phase,true)
				for bone in rig.get_bone_count(): finite=finite and rig.get_bone_global_pose(bone).is_finite()
				var animation:=animator.get_animation(clip)
				for track in animation.get_track_count():
					var path:=animation.track_get_path(track)
					if path.get_subname_count()>0:
						finite=finite and animator.get_node(animator.root_node).get_node_or_null(NodePath(path.get_concatenated_names()))==rig
		check(finite,"native gait and retargeted jump tracks resolve on live rig with finite poses")
		actor.apply_server_appearance({"body":0x191 if not female else 0x190,"hue":1002},[])
		check(actor.human_visual.female!=female,"native sex change replaces visual while preserving avatar root")
		actor.free()
	stage.free()
	print("HUMAN BATCH CHECKS: %d passed / %d total" % [checks-failures,checks])
	quit(0 if failures==0 else 1)
