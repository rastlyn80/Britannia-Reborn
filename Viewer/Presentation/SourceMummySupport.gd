extends "res://Presentation/SourceMageSupport.gd"
## Measured source soles include the imported model's saved floor residual.
var residual_height:=0.
func source_lifts() -> Array[float]:
	var lifts:=super.source_lifts()
	for index in lifts.size():lifts[index]+=residual_height
	return lifts
