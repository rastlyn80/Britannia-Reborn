extends SceneTree
# Bakes each house multi HouseModel.gd supports into a scene in the ignored
# local-multis/houses folder (derived from the owner's install layout; never
# committed). MultiPresenter loads it, or builds the house on the fly.
#   godot --headless --path Viewer --script res://Presentation/BakeHouses.gd
const Multis := preload("res://Presentation/MultiPresenter.gd")
const Houses := preload("res://Presentation/HouseModel.gd")

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://local-multis/houses"))
	var baked := 0
	for id in Houses.SUPPORTED:
		var parts: Array = Multis.components(id)
		if parts.is_empty(): continue
		var house: Node3D = Houses.build(parts,Multis._tiles_of(parts),id)
		for node in house.find_children("*","",true,false): node.owner = house
		var packed := PackedScene.new()
		packed.pack(house)
		var path := "res://local-multis/houses/%x.scn" % id
		if ResourceSaver.save(packed,path) == OK: baked += 1
		house.free()
	print("BAKED HOUSES: %d" % baked)
	quit(0)
