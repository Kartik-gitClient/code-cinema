extends SceneTree


func _init() -> void:
	for path in [
		"res://kit/locations/apartment_dawn.tscn",
		"res://kit/locations/street_breach.tscn",
		"res://kit/locations/mart_red.tscn",
	]:
		var ps: PackedScene = load(path)
		if ps == null:
			print("MISSING ", path)
			continue
		var scene := ps.instantiate()
		var aabb := _aabb(scene, Transform3D.IDENTITY)
		var meshes := _count_type(scene, "MeshInstance3D")
		var lights := _count_type(scene, "Light3D")
		var state := 0
		for n in _all(scene):
			if n.is_in_group("world_state"):
				state += 1
		print("SET ", path)
		print("  nodes=", _all(scene).size(), " meshes=", meshes, " lights=", lights, " state_nodes=", state)
		print("  aabb=", aabb)
		var anchors := []
		for n in _all(scene):
			if n is Marker3D:
				anchors.append(n.name + "@" + str(n.position.snapped(Vector3(0.01, 0.01, 0.01))))
		print("  markers=", anchors)
		scene.free()
	var sp: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://films/save_her/screenplay.json"))
	var shots: Array = sp.get("shots", [])
	var ending: Dictionary = sp.get("ending", {})
	print("SCREENPLAY shots=", shots.size(), " ending=", ending.get("question", ""))
	for shot in shots:
		var s: Dictionary = shot
		print("  ", s.get("id"), " ", s.get("location"), " ", s.get("duration"), "s state=", s.get("state", "-"), " sfx=", s.get("sfx", []).size())
	quit()


func _all(n: Node) -> Array[Node]:
	var out: Array[Node] = [n]
	for c in n.get_children():
		out.append_array(_all(c))
	return out


func _count_type(n: Node, type_name: String) -> int:
	var c := 0
	for x in _all(n):
		if x.is_class(type_name):
			c += 1
	return c


func _aabb(n: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var has := false
	if n is MeshInstance3D and n.mesh != null:
		var local: AABB = xf * n.get_aabb()
		out = local
		has = true
	for c in n.get_children():
		var child_xf := xf
		if c is Node3D:
			child_xf = xf * (c as Node3D).transform
		var a := _aabb(c, child_xf)
		if a.size != Vector3.ZERO:
			if has:
				out = out.merge(a)
			else:
				out = a
				has = true
	return out
