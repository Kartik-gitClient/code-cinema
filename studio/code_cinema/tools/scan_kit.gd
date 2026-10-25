extends SceneTree

## Headless kit scanner. Writes a manifest of every scene under res://kit.
## Usage: godot --headless --path <project> --script res://code_cinema/tools/scan_kit.gd -- --out=res://code_cinema/kit.scanned.json

const KIT_ROOT := "res://kit"
const FOLDERS := ["locations", "characters", "props"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path := "res://code_cinema/kit.scanned.json"
	for arg in args:
		if arg.begins_with("--out="):
			out_path = arg.substr("--out=".length())

	var manifest := {
		"generated_at": Time.get_datetime_string_from_system(),
		"godot": str(Engine.get_version_info().get("string", "")),
		"locations": {},
		"characters": {},
		"props": {},
	}
	for folder in FOLDERS:
		var folder_name: String = str(folder)
		var dir_path: String = KIT_ROOT + "/" + folder_name
		for file_name in _scene_files(dir_path):
			var scene_path: String = dir_path + "/" + file_name
			var key := file_name.get_basename()
			var entry := _scan_scene(scene_path)
			if entry.is_empty():
				continue
			manifest[folder_name][key] = entry
			print("scanned %s -> %s" % [folder_name, key])

	DirAccess.make_dir_recursive_absolute("res://code_cinema")
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	if file == null:
		printerr("Could not write scan manifest: " + out_path)
		quit(1)
		return
	file.store_string(JSON.stringify(manifest, "  "))
	file.close()
	print("kit manifest: " + out_path)
	quit(0)


func _scene_files(dir_path: String) -> PackedStringArray:
	var result := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return result
	for file_name in dir.get_files():
		if file_name.get_extension().to_lower() == "tscn":
			result.append(file_name)
	result.sort()
	return result


func _scan_scene(scene_path: String) -> Dictionary:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		printerr("Could not load scene: " + scene_path)
		return {}
	var instance := packed.instantiate()
	if instance == null:
		return {}
	var entry := {
		"scene": scene_path,
		"root": str(instance.name),
		"nodes": [],
		"anchors": [],
		"animations": {},
		"bounds": {},
	}
	var state := {"bounds": AABB(), "has": false}
	_collect_nodes(instance, entry, state, ".")
	if state["has"]:
		var box: AABB = state["bounds"]
		entry["bounds"] = {
			"min": [box.position.x, box.position.y, box.position.z],
			"max": [box.end.x, box.end.y, box.end.z],
		}
	instance.free()
	return entry


func _collect_nodes(node: Node, entry: Dictionary, state: Dictionary, path: String) -> void:
	var groups: Array = []
	for group in node.get_groups():
		groups.append(str(group))
	entry["nodes"].append({
		"name": str(node.name),
		"type": node.get_class(),
		"path": path,
		"groups": groups,
	})
	if node is Marker3D:
		if not entry["anchors"].has(str(node.name)):
			entry["anchors"].append(str(node.name))
	if groups.has("cc_anchor") and not entry["anchors"].has(str(node.name)):
		entry["anchors"].append(str(node.name))
	if node is AnimationPlayer:
		for anim_name in (node as AnimationPlayer).get_animation_list():
			var animation := (node as AnimationPlayer).get_animation(anim_name)
			entry["animations"][str(anim_name)] = animation.length if animation != null else 0.0
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var box: AABB = (node as MeshInstance3D).get_aabb()
		if not state["has"]:
			state["bounds"] = box
			state["has"] = true
		else:
			state["bounds"] = (state["bounds"] as AABB).merge(box)
	for child in node.get_children():
		var child_path := str(child.name) if path == "." else path + "/" + str(child.name)
		_collect_nodes(child, entry, state, child_path)
