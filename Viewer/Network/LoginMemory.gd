extends RefCounted

var path := "user://last-login.vault"

func request(mode: String, value: Dictionary = {}) -> Dictionary:
	if OS.get_name() != "Windows": return {"ok": false}
	var script := ProjectSettings.globalize_path("res://").path_join("../scripts/login-vault.ps1").simplify_path()
	# Only encrypted bytes reach disk; secrets travel through an anonymous pipe,
	# never process arguments, environment variables or diagnostic output.
	var process := OS.execute_with_pipe("powershell.exe",PackedStringArray([
		"-NoProfile","-NonInteractive","-WindowStyle","Hidden","-ExecutionPolicy","Bypass",
		"-File",script,"-Mode",mode,"-Path",ProjectSettings.globalize_path(path)]),true)
	if process.is_empty(): return {"ok": false}
	var pipe: FileAccess = process.stdio
	pipe.store_line(JSON.stringify(value))
	pipe.flush()
	var response: Variant = JSON.parse_string(pipe.get_line())
	pipe.close()
	process.stderr.close()
	return response if response is Dictionary else {"ok": false}

func save_login(username: String, password: String) -> bool:
	return request("save",{"username":username,"password":password}).get("ok",false)

func load_login() -> Dictionary:
	return request("load")

func forget() -> void:
	request("forget")
