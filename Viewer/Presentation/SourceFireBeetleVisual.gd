extends "res://Presentation/SourceBeetleVisual.gd"
## The source table scales the Giant Beetle by 1.42 and the Fire Beetle by 1.0.
func mount_fittings() -> Dictionary:
	var result := super.mount_fittings()
	const FIRE_TO_GIANT_SCALE := 1.0 / 1.42
	result.saddle *= FIRE_TO_GIANT_SCALE
	result.mouth *= FIRE_TO_GIANT_SCALE
	return result
