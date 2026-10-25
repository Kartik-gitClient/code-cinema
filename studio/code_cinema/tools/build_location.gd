extends SceneTree

## Parametric location builder. Copy this file and edit the geometry for new sets.
## Usage:
##   godot --headless --path <project> --script res://code_cinema/tools/build_location.gd -- \
##     --out=res://kit/locations/room_night.tscn --style=night
##
## The scene is deliberately built from primitives. It is a blocking pass:
## good enough to shoot, easy to replace with a modeled kit later.

const PALETTES := {
	"night": {
		"wall": Color("#3b3630"),
		"floor": Color("#2a211a"),
		"trim": Color("#171310"),
		"fabric": Color("#4a4038"),
		"accent": Color("#c98b4b"),
		"window": Color("#7fa9c9"),
	},
	"cold": {
		"wall": Color("#35414a"),
		"floor": Color("#20272c"),
		"trim": Color("#12171b"),
		"fabric": Color("#3f4c54"),
		"accent": Color("#87b6cf"),
		"window": Color("#a8d4ef"),
	},
	"warm": {
		"wall": Color("#5a4638"),
		"floor": Color("#332419"),
		"trim": Color("#211710"),
		"fabric": Color("#6b5140"),
		"accent": Color("#e0a15f"),
		"window": Color("#d7b98c"),
	},
	"sick": {
		"wall": Color("#474a3b"),
		"floor": Color("#26281f"),
		"trim": Color("#171911"),
		"fabric": Color("#55583f"),
		"accent": Color("#b7c46a"),
		"window": Color("#a9c47e"),
	},
}


func _initialize() -> void:
	var out_path := "res://kit/locations/room_night.tscn"
	var style := "night"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_path = arg.substr("--out=".length())
		elif arg.begins_with("--style="):
			style = arg.substr("--style=".length())
	if not PALETTES.has(style):
		printerr("Unknown style '%s'. Use night, cold, warm or sick." % style)
		quit(1)
		return

	var root := _build_room(PALETTES[style], style)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		printerr("Could not pack location: %s" % error_string(err))
		root.free()
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	err = ResourceSaver.save(packed, out_path)
	if err != OK:
		printerr("Could not save %s: %s" % [out_path, error_string(err)])
	else:
		print("location saved: " + out_path)
	root.free()
	quit(0)


func _build_room(p: Dictionary, style: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Location"
	root.add_to_group("cc_location")

	var wall_mat := _mat(p["wall"], 0.94)
	wall_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var floor_mat := _wood(p["floor"], 0.82)
	var trim_mat := _mat(p["trim"], 0.6)
	var fabric_mat := _mat(p["fabric"], 0.98)
	var metal_mat := _mat(Color("#6d6255"), 0.35, 0.7)
	var accent_mat := _mat(p["accent"], 0.7)
	var window_mat := _mat(p["window"], 0.25, 0.0, p["window"], 0.55)
	window_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var architecture := _node(root, "Architecture", root)
	_box(architecture, root, "Floor", Vector3(7.0, 0.10, 6.2), Vector3(0, -0.05, -0.1), floor_mat, true)
	_box(architecture, root, "Ceiling", Vector3(7.0, 0.12, 6.2), Vector3(0, 3.06, -0.1), wall_mat, true)
	_box(architecture, root, "WallBackLeft", Vector3(3.45, 3.0, 0.12), Vector3(-1.725, 1.5, -3.1), wall_mat, true)
	_box(architecture, root, "WallBackRight", Vector3(3.45, 3.0, 0.12), Vector3(1.725, 1.5, -3.1), wall_mat, true)
	_box(architecture, root, "WallBackTop", Vector3(1.10, 0.78, 0.12), Vector3(0, 2.61, -3.1), wall_mat, true)
	_box(architecture, root, "WallLeft", Vector3(0.12, 3.0, 6.2), Vector3(-3.5, 1.5, -0.1), wall_mat, true)
	_box(architecture, root, "WallRight", Vector3(0.12, 3.0, 6.2), Vector3(3.5, 1.5, -0.1), wall_mat, true)
	_box(architecture, root, "WallFront", Vector3(7.0, 3.0, 0.12), Vector3(0, 1.5, 3.0), wall_mat, true)

	# skirting
	_box(architecture, root, "SkirtBack", Vector3(7.0, 0.16, 0.06), Vector3(0, 0.08, -3.02), trim_mat, false)
	_box(architecture, root, "SkirtLeft", Vector3(0.06, 0.16, 6.0), Vector3(-3.43, 0.08, -0.1), trim_mat, false)
	_box(architecture, root, "SkirtRight", Vector3(0.06, 0.16, 6.0), Vector3(3.43, 0.08, -0.1), trim_mat, false)

	# door frame and a closed door
	_box(architecture, root, "DoorFrameL", Vector3(0.10, 2.26, 0.18), Vector3(-0.60, 1.13, -3.03), trim_mat, false)
	_box(architecture, root, "DoorFrameR", Vector3(0.10, 2.26, 0.18), Vector3(0.60, 1.13, -3.03), trim_mat, false)
	_box(architecture, root, "DoorFrameTop", Vector3(1.30, 0.10, 0.18), Vector3(0, 2.26, -3.03), trim_mat, false)
	_box(architecture, root, "Door", Vector3(1.08, 2.18, 0.07), Vector3(0, 1.09, -3.02), floor_mat, false)
	var knob := _cylinder(architecture, root, "DoorKnob", 0.035, 0.05, 0.05, Vector3(0.42, 1.06, -2.95), metal_mat)
	knob.rotation_degrees.z = 90.0

	# window: an emissive plane set into the left wall with a frame and curtains
	_box(architecture, root, "WindowGlow", Vector3(0.03, 1.35, 1.85), Vector3(-3.43, 1.72, -0.65), window_mat, false)
	_box(architecture, root, "WindowFrameL", Vector3(0.08, 1.52, 0.10), Vector3(-3.39, 1.72, -1.62), trim_mat, false)
	_box(architecture, root, "WindowFrameR", Vector3(0.08, 1.52, 0.10), Vector3(-3.39, 1.72, 0.32), trim_mat, false)
	_box(architecture, root, "WindowFrameT", Vector3(0.08, 0.10, 1.98), Vector3(-3.39, 2.50, -0.65), trim_mat, false)
	_box(architecture, root, "WindowFrameB", Vector3(0.08, 0.10, 1.98), Vector3(-3.39, 0.94, -0.65), trim_mat, false)
	_box(architecture, root, "WindowBarV", Vector3(0.06, 1.40, 0.05), Vector3(-3.37, 1.72, -0.65), trim_mat, false)
	_box(architecture, root, "WindowBarH", Vector3(0.06, 0.05, 1.92), Vector3(-3.37, 1.72, -0.65), trim_mat, false)
	_box(architecture, root, "CurtainL", Vector3(0.06, 2.05, 0.38), Vector3(-3.28, 1.45, -1.82), fabric_mat, false)
	_box(architecture, root, "CurtainR", Vector3(0.06, 2.05, 0.38), Vector3(-3.28, 1.45, 0.52), fabric_mat, false)

	# ceiling beams
	for index in range(3):
		_box(architecture, root, "Beam%d" % index, Vector3(7.0, 0.16, 0.18), Vector3(0, 2.93, -2.0 + index * 1.9), trim_mat, false)

	# picture frames
	_frame(architecture, root, "FrameA", Vector3(0.85, 1.15, 0.06), Vector3(-1.7, 1.9, -3.02), trim_mat, accent_mat)
	_frame(architecture, root, "FrameB", Vector3(0.55, 0.75, 0.06), Vector3(1.95, 1.75, -3.02), trim_mat, fabric_mat)

	var furniture := _node(root, "Furniture", root)
	_box(furniture, root, "Rug", Vector3(3.3, 0.02, 2.2), Vector3(0.1, 0.015, 0.15), _mat(Color("#4d2f28"), 0.98), false)
	_box(furniture, root, "RugInner", Vector3(2.9, 0.021, 1.8), Vector3(0.1, 0.017, 0.15), _mat(Color("#6a4135"), 0.98), false)
	_box(furniture, root, "TableTop", Vector3(2.0, 0.09, 1.0), Vector3(1.05, 0.74, 0.35), floor_mat, true)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(furniture, root, "TableLeg", Vector3(0.09, 0.72, 0.09), Vector3(1.05 + sx * 0.82, 0.36, 0.35 + sz * 0.36), floor_mat, true)
	_box(furniture, root, "RadioBody", Vector3(0.42, 0.26, 0.20), Vector3(0.55, 0.90, 0.30), trim_mat, false)
	_box(furniture, root, "RadioDial", Vector3(0.30, 0.10, 0.01), Vector3(0.55, 0.93, 0.195), _mat(Color("#e0b15a"), 0.3, 0.0, Color("#ffc46b"), 2.4), false)
	_box(furniture, root, "RadioSpeaker", Vector3(0.11, 0.14, 0.01), Vector3(0.72, 0.88, 0.195), _mat(Color("#2a2520"), 0.9), false)

	_box(furniture, root, "CouchBase", Vector3(2.3, 0.42, 0.95), Vector3(-1.30, 0.26, 0.75), fabric_mat, true)
	_box(furniture, root, "CouchBack", Vector3(2.3, 0.72, 0.18), Vector3(-1.30, 0.75, 1.18), fabric_mat, true)
	_box(furniture, root, "CouchCushionL", Vector3(1.02, 0.16, 0.80), Vector3(-1.82, 0.54, 0.70), _mat(p["fabric"].lightened(0.08), 0.98), false)
	_box(furniture, root, "CouchCushionR", Vector3(1.02, 0.16, 0.80), Vector3(-0.78, 0.54, 0.70), _mat(p["fabric"].lightened(0.06), 0.98), false)

	# shelf on the right wall
	_box(furniture, root, "ShelfSideA", Vector3(0.08, 1.9, 0.55), Vector3(3.20, 0.95, -1.65), floor_mat, true)
	_box(furniture, root, "ShelfSideB", Vector3(0.08, 1.9, 0.55), Vector3(3.20, 0.95, 1.55), floor_mat, true)
	for index in range(4):
		_box(furniture, root, "ShelfPlank%d" % index, Vector3(0.52, 0.06, 3.1), Vector3(3.20, 0.35 + index * 0.48, -0.05), floor_mat, false)
	for index in range(3):
		var book_color := Color("#5c3d2e") if index % 2 == 0 else Color("#3d4a52")
		_box(furniture, root, "Book%d" % index, Vector3(0.18, 0.26 + index * 0.03, 0.10), Vector3(3.18, 0.52 + index * 0.48, -0.55 + index * 0.16), _mat(book_color, 0.9), false)

	# practical lamp
	var lamp := _node(root, "PracticalLamp", root)
	_cylinder(lamp, root, "LampBase", 0.20, 0.24, 0.04, Vector3(2.55, 0.02, -0.55), metal_mat)
	_cylinder(lamp, root, "LampPole", 0.025, 0.025, 1.45, Vector3(2.55, 0.74, -0.55), metal_mat)
	_cylinder(lamp, root, "LampShade", 0.18, 0.30, 0.32, Vector3(2.55, 1.46, -0.55), _mat(Color("#d8b27a"), 0.95, 0.0, Color("#e3a15c"), 0.35))
	var light := OmniLight3D.new()
	light.name = "LampLight"
	light.position = Vector3(2.55, 1.42, -0.55)
	light.light_color = Color("#ffb46b")
	light.light_energy = 1.35
	light.omni_range = 6.5
	light.omni_attenuation = 1.4
	light.shadow_enabled = true
	lamp.add_child(light)
	_own(light, root)

	var anchors := _node(root, "Anchors", root)
	_marker(anchors, root, "room_wide", Vector3(0.0, 1.70, 2.35))
	_marker(anchors, root, "door_pov", Vector3(0.0, 1.62, 0.35))
	_marker(anchors, root, "door_close", Vector3(0.0, 1.55, -1.65))
	_marker(anchors, root, "door", Vector3(0.0, 1.05, -3.0))
	_marker(anchors, root, "window", Vector3(-1.55, 1.70, -0.55))
	_marker(anchors, root, "table", Vector3(1.05, 1.15, 0.35))
	_marker(anchors, root, "low_corner", Vector3(-2.55, 0.62, 1.95))

	return root


func _node(parent: Node3D, name: String, owner: Node) -> Node3D:
	var node := Node3D.new()
	node.name = name
	parent.add_child(node)
	_own(node, owner)
	return node


func _own(node: Node, owner: Node) -> void:
	node.owner = owner


func _mat(color: Color, roughness: float = 0.9, metallic: float = 0.0, emission: Color = Color(0, 0, 0), energy: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	if energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = energy
	return mat


func _wood(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := _mat(color, roughness)
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.028
	noise.fractal_octaves = 3
	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.seamless = true
	texture.noise = noise
	mat.albedo_texture = texture
	mat.uv1_scale = Vector3(2.5, 2.5, 2.5)
	return mat


func _box(parent: Node3D, owner: Node, name: String, size: Vector3, position: Vector3, material: Material, collide: bool) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = name
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
	_own(instance, owner)
	if collide:
		var body := StaticBody3D.new()
		body.name = name + "Body"
		var shape := CollisionShape3D.new()
		shape.name = name + "Shape"
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		instance.add_child(body)
		body.add_child(shape)
		_own(body, owner)
		_own(shape, owner)
	return instance


func _cylinder(parent: Node3D, owner: Node, name: String, top: float, bottom: float, height: float, position: Vector3, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 24
	var instance := MeshInstance3D.new()
	instance.name = name
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
	_own(instance, owner)
	return instance


func _frame(parent: Node3D, owner: Node, name: String, size: Vector3, position: Vector3, frame_mat: Material, inner_mat: Material) -> void:
	_box(parent, owner, name + "Outer", size, position, frame_mat, false)
	_box(parent, owner, name + "Inner", Vector3(size.x * 0.78, size.y * 0.78, size.z + 0.01), position + Vector3(0, 0, 0.01), inner_mat, false)


func _marker(parent: Node3D, owner: Node, name: String, position: Vector3) -> Marker3D:
	var marker := Marker3D.new()
	marker.name = name
	marker.position = position
	marker.add_to_group("cc_anchor")
	parent.add_child(marker)
	_own(marker, owner)
	return marker
