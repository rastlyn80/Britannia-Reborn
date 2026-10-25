extends SceneTree

const Protocol = preload("res://Network/LoginProtocol.gd")
var client: Node
var frames := 0

func _initialize() -> void:
	client = Protocol.new()
	root.add_child(client)
	client.servers_received.connect(func(servers: Array):
		if servers.is_empty():
			push_error("No server advertised")
			quit(1)
			return
		print("LIVE LOGIN PASS: server list received (",servers.size(),")")
		client.select_server(servers[0].index))
	client.relay_received.connect(func(address: String, port: int, _token: int):
		print("LIVE LOGIN PASS: game relay ",address,":",port)
		client.close()
		quit(0))
	client.failed.connect(func(reason: String):
		push_error(reason)
		quit(1))
	client.start(OS.get_environment("UO_DEV_USER"), OS.get_environment("UO_DEV_PASSWORD"))

func _process(_delta: float) -> bool:
	frames += 1
	if frames > 4000:
		push_error("Smoke test watchdog timeout")
		quit(1)
	return false
