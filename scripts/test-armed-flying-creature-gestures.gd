extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Game := preload("res://Network/GameSession.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Exact := preload("res://../scripts/test-quadruped-actions.gd")
const Corpses := preload("res://Presentation/CorpseModels.gd")
const StaffClearance := preload("res://../scripts/skeletal-mage-staff-clearance.gd")
const ROUTES := {
	764:{4:"Attack",6:"StepSlash",11:"Fidget",14:"Cast2",15:"JukaStagger",16:"JukaStagger",
		17:"Fidget",18:"JukaShoulderCheck"},
	40:{2:"Death",3:"Death",4:"Attack",6:"BalronRake",10:"Hit",11:"Fidget",12:"DaemonCast",
		13:"BalronStagger",15:"BalronGuard",16:"BalronGuard",17:"Fidget",18:"BalronPause",21:"AirDeath"},
	148:{4:"Attack",5:"StaffPush",6:"StaffSlash",10:"Hit",11:"MageStaffCheck",15:"StaffRecoil",
		16:"StaffRecoil",17:"Fidget",18:"StaffRaise"},
}
const FITTED := {764:[6,15,16,18],40:[6,13,15,16,18,21],148:[5,6,15,16,18]}

func _initialize() -> void:
	create_timer(40.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var samples := 0
	load_routes()
	for body: int in ROUTES:
		var row := Registry.entry(body)
		var routes: Dictionary = ROUTES[body]
		game.entities[body] = {"serial":body,"body":body,"hue":0x8035}
		for treatment: String in ["original","rounded","modern"]:
			assert(FileAccess.get_sha256(row.assets[treatment]) == row.authored_action_scene_sha256[treatment])
			var actor := Registry.create(body)
			actor.treatment = treatment
			root.add_child(actor)
			actor.apply_identity(body,0x8035)
			actor.set_process(false)
			actor.set_physics_process(false)
			var rig: Skeleton3D = actor.skeleton
			var player: AnimationPlayer = actor.animator
			var mesh := actor.model.find_children("*","MeshInstance3D",true,false)[0] as MeshInstance3D
			var skin := Ground.skin_points(mesh,rig)
			Exact.check_earlier_keys(player,row.classic_gesture_base_assets[treatment])
			var staff := staff_data(actor,mesh,rig) if body == 148 else {}
			for slot: int in routes:
				var packet := PackedByteArray([0x6e])
				packet.append_array(Wire.uint_be(body,4))
				packet.append_array(PackedByteArray([0,slot,0,5,0,1,1,0,0]))
				game._handle(packet)
				assert(actor.receive_action(game.last_mobile_actions[body]) and actor.current_clip==routes[slot])
				if body == 40:
					assert(actor.dead == (slot in [2,3,21]))
					actor.dead = false
					actor.model.position -= actor.fall.shift
					actor.fall.shift = Vector3.ZERO
					actor.fall.plane = {}
				player.stop()
				player.play(actor.current_clip,0.0)
				player.advance(0.0)
				var gaps: Array[float] = []
				for frame in 61:
					player.seek(player.current_animation_length*float(frame)/60.0,true)
					rig.force_update_all_bone_transforms()
					gaps.append(Ground.minimum_plane_gap(skin,rig,rig.global_transform,Vector3.ZERO,Vector3.UP))
					assert(actor.native_hue==0x8035 and actor.position.is_zero_approx() and is_finite(gaps[-1]))
					if body == 148 and slot in FITTED[body]:
						check_staff(rig,staff)
					samples += 1
				if slot in FITTED[body]:
					assert(gaps.min()>-0.007, "Body %d group %d min %f" % [body,slot,gaps.min()])
				if body==40 and slot==21:
					assert(gaps[0]>1.4 and gaps[-1]<0.008)
				print(body," ",treatment," ",slot," ",routes[slot]," floor ",gaps.min(),"..",gaps.max())
			actor.free()
		for hue: int in [0,53,0x8035]:
			var corpse := Corpses.build(body,hue)
			assert(corpse != null and corpse.get_meta("static_cadaver"))
			assert(corpse.get_meta("graphic_id") == 0x2006 and corpse.get_meta("corpse_body") == body)
			assert(corpse.get_meta("native_hue") == hue and corpse.find_children("*","Skeleton3D",true,false).is_empty())
			corpse.free()
	game.free()
	print("JUKA WARRIOR, BALRON AND BONE MAGI: ",samples," decoded samples with staff clearance, exact prior keys and nine corpse hues")
	quit()

func staff_data(actor: Node3D, body: MeshInstance3D, rig: Skeleton3D) -> Dictionary:
	var mesh := actor.find_child("SkeletonMageStaff",true,false) as MeshInstance3D
	assert(mesh != null and mesh.get_active_material(0) == mesh.mesh.surface_get_material(0))
	var joint := mesh.skin.get_bind_bone(0)
	var grip := rig.get_bone_parent(joint)
	assert(rig.get_bone_name(grip) == "cp_grasp_rhand")
	return {"joint":joint,"grip":grip,"skin":Ground.skin_points(mesh,rig),"clearance":StaffClearance.new(body,rig)}

func check_staff(rig: Skeleton3D, staff: Dictionary) -> void:
	var pose := rig.get_bone_global_pose(staff.joint)
	assert(pose.origin.distance_to(rig.get_bone_global_pose(staff.grip).origin) < 0.0001)
	staff.clearance.update_pose()
	assert(not staff.clearance.crosses_staff(rig.global_transform * pose))
	assert(Ground.minimum_plane_gap(staff.skin,rig,rig.global_transform,Vector3.ZERO,Vector3.UP)>0.20)

func load_routes() -> void:
	Registry.load_index()
	if not "--candidate" in OS.get_cmdline_user_args():
		return
	var path := "res://../work/creatures/armed_flying_creature_gestures/candidates.json"
	var records: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(records.size() == 4)
	var rows := {}
	for record: Dictionary in records:
		var body := int(record.body)
		assert(not rows.has(body) or rows[body] == record.presentation)
		rows[body] = record.presentation
	assert(rows.size() == ROUTES.size())
	Registry.entries.merge(rows,true)
