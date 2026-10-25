extends RefCounted
const Tables = preload("res://Network/WireTables.gd")
var node := 0

func decode(bytes: PackedByteArray) -> PackedByteArray:
	var output := PackedByteArray()
	for byte in bytes:
		for bit in range(7,-1,-1):
			node = Tables.TREE[node * 2 + (0 if byte & (1 << bit) else 1)]
			if node == -256:
				node = 0
				break # packet terminator discards padding to the next byte
			if node <= 0:
				output.append(-node)
				node = 0
	return output
