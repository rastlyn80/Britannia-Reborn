extends "res://Presentation/SmallSnakeVisual.gd"
## Dense posed triangles follow the original four-slot control surface.
signal landmarks_changed
var pose_entry:=preload("res://Presentation/SourceVariantPoseEntry.gd").new()
var blend_remaining:=0.
var clearance_lift:=Vector3.ZERO
var control_skin: Dictionary={}
func _capture_variant_frame() -> void:pose_entry.capture_frame(self)
func _ready() -> void:
	super._ready()
	var render_mesh: MeshInstance3D=model.find_children("*","MeshInstance3D",true,false)[0]
	var control:=render_mesh
	if treatment!="original":
		var source: Node3D=load(str(entry.assets.original)).instantiate()
		var original: MeshInstance3D=source.find_children("*","MeshInstance3D",true,false)[0]
		assert(original.transform==render_mesh.transform and original.skeleton==render_mesh.skeleton)
		control=MeshInstance3D.new();control.name="SourceContactReference";control.mesh=original.mesh;control.skin=original.skin
		control.transform=original.transform;control.skeleton=original.skeleton;control.visible=false
		render_mesh.get_parent().add_child(control);source.free()
	# Replace the inherited helper synchronously, before its first modifier tick.
	# Neither eight-slot weights nor conditional inverse binds are truncated.
	contact.free();contact=preload("res://Presentation/SourcePlaneSoleSupport.gd").new();skeleton.add_child(contact)
	contact.include_toe_descendants=true;contact.model_root=model
	contact.flat_basis=source_model_basis.scaled_local(default_model_scale)
	contact.configure(control,entry.get("limb_support","")=="quadruped")
	control_skin=preload("res://Presentation/SourceGroundLookup.gd").skin_points(control,skeleton)
	contact.modification_processed.connect(support_control_plane)
	contact.modification_processed.connect(update_landmarks)
	pose_entry.configure(self,model.position)
	animator.mixer_applied.connect(release_clearance)
	animator.mixer_applied.connect(apply_variant_entry)
func update_landmarks() -> void:
	super.update_landmarks()
	if not influence_bounds.is_empty():landmarks_changed.emit()
func apply_variant_entry() -> void:
	if pose_entry.active:pose_entry.support(self)
func release_clearance() -> void:
	model.position-=clearance_lift;clearance_lift=Vector3.ZERO
func support_control_plane() -> void:
	if pose_entry.active or contact.contacts.is_empty():return
	var hit: Dictionary=contact.contacts.values()[0]
	var gap:=preload("res://Presentation/SourceGroundLookup.gd").minimum_plane_gap(control_skin,skeleton,skeleton.global_transform,hit.position,hit.normal)
	# A plane's minimum over a posed triangle is at a source corner. The dense
	# surface adds bounded1.5mm shaping;2mm clearance covers that offset.
	if gap<.002:
		var previous: Vector3=model.position;model.global_position+=hit.normal*(.002-gap);clearance_lift=model.position-previous
func begin_death_from(source: Node3D) -> float:return pose_entry.begin(self,source)
