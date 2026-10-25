extends RefCounted
var strings := {}
func _init() -> void:
 if FileAccess.file_exists("res://cliloc.local.json"):
  var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://cliloc.local.json"))
  if parsed is Dictionary: strings = parsed
func resolve(number: int, arguments: String = "") -> String:
 var value: String = strings.get(str(number),"Server label #%d" % number)
 var fields := arguments.split("\t")
 var pattern := RegEx.new()
 pattern.compile("~([0-9]+)_[^~]*~")
 var matches := pattern.search_all(value)
 for i in range(matches.size()-1,-1,-1):
  var argument := int(matches[i].get_string(1))-1
  if argument < 0 or argument >= fields.size(): continue
  var replacement: String = fields[argument]
  if replacement.begins_with("#") and replacement.substr(1).is_valid_int(): replacement = strings.get(replacement.substr(1),replacement)
  value = value.substr(0,matches[i].get_start())+replacement+value.substr(matches[i].get_end())
 return value
func item_name(id: int) -> String:
 return strings.get(str(1020000+id),"Item 0x%04X" % id)
