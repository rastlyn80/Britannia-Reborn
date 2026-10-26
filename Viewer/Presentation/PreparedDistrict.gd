extends Resource
# Local generated content. Packed integer source data stays off the scene tree.
@export var origin := Vector2i.ZERO
@export var scene: PackedScene
@export var root_scene: PackedScene
@export var parts: Array[PackedScene]=[]
@export var land := PackedInt32Array()
@export var statics := PackedInt32Array()

func decode() -> Dictionary:
 var terrain: Array = []
 var objects: Array = []
 for i in range(0,land.size(),2):
  var cell := i/2
  terrain.append({"x":origin.x+cell%64,"y":origin.y+cell/64,"id":land[i],"z":land[i+1]})
 for i in range(0,statics.size(),4):
  objects.append({"x":origin.x+(statics[i+1]&63),"y":origin.y+(statics[i+1]>>6),"id":statics[i],"z":statics[i+2],"hue":statics[i+3]})
 return {"terrain":terrain,"statics":objects}
