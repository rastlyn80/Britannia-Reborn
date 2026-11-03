extends "res://Presentation/CreatureDeathTests.gd"
## Decode real packet formats into the candidate; no live-server/GPU claim.
const ActualAvatar=preload("res://Presentation/HumanAvatar.gd")
const Corpses=preload("res://Presentation/CorpseModels.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
func _initialize() -> void:
	create_timer(120.).timeout.connect(func():push_error("Mummy death deadline");quit(1));call_deferred("run")
func release_pose(visual: Node3D) -> void:
	# Release overrides while their instances still exist, matching CorpseModels.
	for mesh: MeshInstance3D in visual.model.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():mesh.set_surface_override_material(surface,null)
	visual.free()
func run() -> void:
	Registry.load_index();var saved:=Registry.entries.duplicate(true);var accepted_path:="res://local-art/creatures/accepted-index.json";var accepted_pin:=FileAccess.get_sha256(accepted_path)
	var prep_path:="res://local-art/creatures/mummies/preparation.json";var prep_pin:=FileAccess.get_sha256(prep_path);var ground_path:="res://local-art/creatures/walking_dead_mummy-ground.json";var ground_pin:=FileAccess.get_sha256(ground_path)
	var prep: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(prep_path));Registry.entries[154]=prep.models[0]
	var runtime: Dictionary={}
	for name in ["MummyDeathTests.gd","CreatureDeathTests.gd","CreatureDeaths.gd","SourceMummyVisual.gd","SourceRenderedPose.gd","SourcePoseEntry.gd","SourceMummySupport.gd","SourceMageVisual.gd","SourceMageSupport.gd","MeasuredCreatureVisual.gd","MeasuredCreatureSupport.gd","SourceBipedVisual.gd","SourceBipedSupport.gd","CreatureVisual.gd","SourceMountContact.gd","SourceGroundLookup.gd","SkinGeometry.gd","HumanAvatar.gd","CorpseModels.gd","WorldItems.gd","CreatureRegistry.gd"]:runtime[name]=FileAccess.get_sha256("res://Presentation/"+name)
	var game:=Game.new();root.add_child(game);game.set_process(false);var arena:=Arena.new();root.add_child(arena);var items:=Items.new();arena.add_child(items);var deaths:=Deaths.new();arena.add_child(deaths);deaths.configure(arena,game,items)
	var records: Array=[];var origin:=Vector3(3.,.25,-4.)
	for from: String in ["Walk","Run","Attack"]:
		for hue: int in [53,0x8035]:
			for direction: int in [0,5]:
				for with_corpse: bool in [false,true]:
					var serial:=7000154;var corpse:=0x40010154 if with_corpse else 0
					var actor:=ActualAvatar.new();actor.initial_body=154;arena.add_child(actor);actor.position=origin;actor.set_process(false);actor.set_physics_process(false)
					var entity:={"serial":serial,"body":154,"hue":hue,"direction":direction,"flags":0,"x":1100,"y":1700,"z":0}
					actor.apply_server_appearance(entity,[]);arena.avatars[serial]=actor;game.entities[serial]=entity.duplicate(true)
					var source: Node3D=actor.horse_visual;source.set_process(false);source.set_physics_process(false);source.contact.active=false;source.contact.enabled=false;source.animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
					source.play(from,0.);source.animator.seek(source.animator.get_animation(from).length*.37,true);source.animator.advance(0.);source.skeleton.force_update_all_bone_transforms()
					var poses: Array[Transform3D]=[]
					for bone in source.skeleton.get_bone_count():poses.append(source.skeleton.get_bone_pose(bone))
					var original: Animation=source.animator.get_animation("Death");var length:=original.length
					var holder:=Node3D.new();items.add_child(holder);var collider:=StaticBody3D.new();holder.add_child(collider);collider.collision_layer=4
					if with_corpse:items.nodes[corpse]=holder
					game._handle(packet(serial,corpse))
					check(deaths.active.has(serial),"Decoded0xAF starts the actual registered Mummy death renderer")
					if not deaths.active.has(serial):actor.free();holder.free();continue
					var visual: Node3D=deaths.active[serial].visual;visual.set_process(false);visual.set_physics_process(false);visual.animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
					check(visual.native_body==154 and visual.native_hue==hue and visual.current_clip=="Death" and visual.dead,"Native death retains body/hue and the original source category")
					check(is_equal_approx(visual.action_remaining,length+.08) and source.animator.get_animation("Death")==original and original.length==length,"Only the death snapshot owns the short pose-entry clip")
					check(visual.global_position==source.global_position and visual.model.position==source.model.position and is_equal_approx(visual.rotation.y,PI-float(direction)*PI/4.),"First death frame retains displayed location/model offset and native facing")
					check(visual.get_meta("native_action",{}).is_empty() and game.entities[serial]==entity and not actor.visible,"0xAF does not fabricate0x6E or alter authoritative mobile data")
					for bone in visual.skeleton.get_bone_count():check(visual.skeleton.get_bone_pose(bone).is_equal_approx(poses[bone]),"First death frame retains every displayed source bone pose")
					if with_corpse:check(not holder.visible and collider.collision_layer==4,"Pending corpse hides its model while keeping interaction active")
					source.set_hue(1002);check(visual.native_hue==hue and visual.hue==hue,"Living material rebuild cannot mutate the death snapshot")
					game._handle(packet(serial,corpse));check(deaths.active.size()==1,"Repeated0xAF does not duplicate a Mummy death")
					var minimum:=INF;var maximum:=0.;var previous_time:=0.
					for time: float in [.009,.027,.051,.079,.081,.171,(length+.08)*.5,length+.08]:
						var delta:=time-previous_time;previous_time=time
						visual._process(delta);visual.animator.advance(delta);visual.skeleton.force_update_all_bone_transforms()
						var mesh: MeshInstance3D=visual.model.find_children("*","MeshInstance3D",true,false)[0];var box:=Geometry.deformed_bounds(mesh,visual.skeleton);var body_gap:=box.position.y-origin.y
						minimum=minf(minimum,body_gap);maximum=maxf(maximum,absf(body_gap));check(is_finite(body_gap) and absf(body_gap)<.008,"Complete Mummy body remains grounded through pose-entry and original collapse")
						check(visual.global_position==origin,"Death support preserves the native world anchor")
					var posed:=Corpses.posed(154,hue);check(posed!=null,"The same native body/hue builds its final static corpse")
					check(visual.blend_remaining==0. and visual.action_remaining<.00001,"Real elapsed time finishes the entry window and complete collapse")
					if posed!=null:
						for bone in visual.skeleton.get_bone_count():check(visual.skeleton.get_bone_pose(bone).is_equal_approx(posed.skeleton.get_bone_pose(bone)),"Animated pose-entry death ends on the original static corpse skeleton")
						release_pose(posed)
					var remove:=PackedByteArray([0x1d]);remove.append_array(Wire.uint_be(serial,4));game._handle(remove);arena.avatars.erase(serial);actor.free()
					check(is_instance_valid(visual),"Snapshot survives removal of its native mobile")
					deaths._process(float(deaths.active[serial].remaining)+.01);check(deaths.active.is_empty() and deaths.held_corpses.is_empty(),"Finished Mummy death releases temporary transition state")
					if with_corpse:check(holder.visible,"Final static cadaver becomes visible after the complete collapse")
					items.nodes.erase(corpse);holder.free();records.append({"from":from,"hue":hue,"direction":direction,"with_corpse":with_corpse,"minimum_body_gap_m":minimum,"maximum_body_error_m":maximum,"source_duration_s":length,"entry_s":.08});await process_frame
	game.ended.emit();Registry.entries=saved
	check(accepted_pin==FileAccess.get_sha256(accepted_path),"Prepared native-format death tests leave acceptance unchanged")
	check(prep_pin==FileAccess.get_sha256(prep_path) and ground_pin==FileAccess.get_sha256(ground_path),"Prepared source and curves unchanged throughout death tests")
	for name: String in runtime:check(runtime[name]==FileAccess.get_sha256("res://Presentation/"+name),"Death source remains unchanged:"+name)
	var report:={"checks":checks,"failures":failures,"cases":records,"runtime_sha256":runtime,"preparation_sha256":prep_pin,"ground_measurement_sha256":ground_pin,"scope":"Client-decoded0xAF/0x1D with in-memory Mummy registry and actual avatar/death presenter; exact first source bone/model position,80ms private entry, off-grid body floor, native body/hue/facing/data, repeated packets and source removal, final original corpse skeleton and visibility/collider lifecycle. No actual native server, rendered entry, sloped death/garments/loot or family acceptance."}
	FileAccess.open("res://../work/creatures/mummies/death-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("MUMMY DEATH: ",checks," checks / ",failures," failures / ",records.size()," cases");quit(1 if failures else 0)
