extends SceneTree

## Builds the starter kit scenes with primitives, lights, materials and animations.
## Run once after creating the studio:
##   godot --headless --path <studio> --script res://code_cinema/tools/author_starter.gd
##
## Edit this file freely to create your own locations/props. It is a working
## example of the "blockout -> light -> dress -> atmosphere" scene recipe.

const OUT := "res://kit"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "/locations"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "/characters"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "/props"))

	_build_room()
	_build_human("zombie", true)
	_build_human("survivor", false)
	_build_radio()
	_build_door()
	print("Code Cinema: starter kit scenes written.")
	quit()


# --------------------------------------------------------------------------
# Materials and primitives
# --------------------------------------------------------------------------

func _mat(hex: String, rough := 0.85, metal := 0.0, emission := "", emission_energy := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.from_string(hex, Color.WHITE)
	m.roughness = rough
	m.metallic = metal
	if emission != "":
		m.emission_enabled = true
		m.emission = Color.from_string(emission, Color.WHITE)
		m.emission_energy_multiplier = emission_energy
	return m


func _box(parent: Node3D, node_name: String, size: Vector3, pos: Vector3, mat: Material, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


func _cyl(parent: Node3D, node_name: String, radius: float, height: float, pos: Vector3, mat: Material, rot_deg := Vector3.ZERO, top_radius := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = 20
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


func _sphere(parent: Node3D, node_name: String, radius: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 20
	mesh.rings = 10
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _asset(parent: Node3D, node_name: String, res_path: String, pos: Vector3, rot_deg := Vector3.ZERO, s := 1.0) -> Node3D:
	var packed := load(res_path) as PackedScene
	if packed == null:
		push_error("Code Cinema: cannot load asset " + res_path)
		return null
	var node := packed.instantiate() as Node3D
	if node == null:
		push_error("Code Cinema: asset root is not Node3D: " + res_path)
		return null
	node.name = node_name
	node.position = pos
	node.rotation_degrees = rot_deg
	node.scale = Vector3.ONE * s
	parent.add_child(node)
	return node


func _soft_disc() -> GradientTexture2D:
	var g := Gradient.new()
	g.add_point(0.0, Color(1, 1, 1, 1))
	g.add_point(0.55, Color(1, 1, 1, 0.8))
	g.add_point(1.0, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	return tex


func _marker(parent: Node3D, node_name: String, pos: Vector3, look_target = null) -> Marker3D:
	var m := Marker3D.new()
	m.name = node_name
	m.position = pos
	if look_target != null:
		var dir: Vector3 = look_target - pos
		if dir.length() > 0.001:
			m.transform = Transform3D(Basis.looking_at(dir.normalized(), Vector3.UP), pos)
	parent.add_child(m)
	return m


func _omni(parent: Node3D, node_name: String, pos: Vector3, color: String, energy: float, range_: float, shadows := true) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = node_name
	l.position = pos
	l.light_color = Color.from_string(color, Color.WHITE)
	l.light_energy = energy
	l.omni_range = range_
	l.omni_attenuation = 1.2
	l.shadow_enabled = shadows
	l.shadow_bias = 0.04
	parent.add_child(l)
	return l


func _spot(parent: Node3D, node_name: String, pos: Vector3, target: Vector3, color: String, energy: float, range_: float, angle: float) -> SpotLight3D:
	var l := SpotLight3D.new()
	l.name = node_name
	l.transform = Transform3D(Basis.looking_at((target - pos).normalized(), Vector3.UP), pos)
	l.light_color = Color.from_string(color, Color.WHITE)
	l.light_energy = energy
	l.spot_range = range_
	l.spot_angle = angle
	l.spot_angle_attenuation = 1.0
	l.shadow_enabled = true
	l.shadow_bias = 0.05
	parent.add_child(l)
	return l


func _save(root: Node3D, path: String) -> void:
	_own_tree(root, root)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		push_error("pack failed for " + path + ": " + str(err))
		root.free()
		return
	err = ResourceSaver.save(packed, path)
	root.free()
	if err != OK:
		push_error("save failed for " + path + ": " + str(err))
	else:
		print("  wrote ", path)


func _own_tree(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_own_tree(child, owner)


# --------------------------------------------------------------------------
# Room
# --------------------------------------------------------------------------

func _build_room() -> void:
	var root := Node3D.new()
	root.name = "RoomNight"

	var wall := _mat("#272724", 0.96)
	var wall_dark := _mat("#1c1c1a", 0.98)
	var floor_a := _mat("#3a2b20", 0.78)
	var floor_b := _mat("#453426", 0.74)
	var floor_c := _mat("#2f2219", 0.82)
	var trim := _mat("#4a3424", 0.8)
	var wood := _mat("#5a3d28", 0.72)
	var wood_dark := _mat("#3b281a", 0.8)
	var metal := _mat("#6b6a66", 0.34, 0.8)
	var metal_dark := _mat("#2c2c2b", 0.4, 0.7)
	var fabric := _mat("#2f3a32", 0.98)
	var fabric_warm := _mat("#5a2a24", 0.98)
	var rug := _mat("#4a1f22", 0.99)
	var paper := _mat("#c8bfa8", 0.9)
	var paper_dark := _mat("#7d7565", 0.95)
	var black := _mat("#0b0b0b", 0.95)
	var blood := _mat("#3d0a0a", 0.55)

	# Floor: individual planks give the room scale and a built-in grid of lines.
	for i in range(8):
		var x := -3.5 + float(i)
		var mat := floor_a
		if i % 3 == 1:
			mat = floor_b
		elif i % 3 == 2:
			mat = floor_c
		_box(root, "FloorPlank%d" % i, Vector3(0.965, 0.1, 8.0), Vector3(x, -0.05, 0.0), mat)
	_box(root, "Ceiling", Vector3(8.0, 0.12, 8.0), Vector3(0.0, 3.26, 0.0), wall_dark)

	# Walls
	_box(root, "WallBack", Vector3(8.0, 3.2, 0.2), Vector3(0.0, 1.6, -4.0), wall)
	_box(root, "WallFront", Vector3(8.0, 3.2, 0.2), Vector3(0.0, 1.6, 4.0), wall)
	_box(root, "WallLeft", Vector3(0.2, 3.2, 8.0), Vector3(-4.0, 1.6, 0.0), wall)
	_box(root, "WallRight", Vector3(0.2, 3.2, 8.0), Vector3(4.0, 1.6, 0.0), wall)

	# Baseboards + chair rail
	_box(root, "BaseboardBack", Vector3(7.8, 0.18, 0.06), Vector3(0.0, 0.09, -3.88), trim)
	_box(root, "BaseboardFront", Vector3(7.8, 0.18, 0.06), Vector3(0.0, 0.09, 3.88), trim)
	_box(root, "BaseboardLeft", Vector3(0.06, 0.18, 7.8), Vector3(-3.88, 0.09, 0.0), trim)
	_box(root, "BaseboardRight", Vector3(0.06, 0.18, 7.8), Vector3(3.88, 0.09, 0.0), trim)

	# Rug + dressed set
	_box(root, "Rug", Vector3(3.5, 0.025, 2.6), Vector3(0.4, 0.016, 0.65), rug)
	_asset(root, "PaintedSofa", "res://open_assets/painted_wooden_sofa/painted_wooden_sofa.gltf", Vector3(3.28, 0.0, 0.65), Vector3(0, 90, 0), 0.82)
	_asset(root, "CoffeeTable", "res://open_assets/industrial_coffee_table/industrial_coffee_table.gltf", Vector3(0.78, 0.349, 0.9), Vector3(0, 8, 0), 0.92)
	_asset(root, "SideTable", "res://open_assets/industrial_coffee_table/industrial_coffee_table.gltf", Vector3(2.55, 0.243, 2.02), Vector3(0, 90, 0), 0.64)
	_asset(root, "VintageCabinet", "res://open_assets/vintage_cabinet_01/vintage_cabinet_01.gltf", Vector3(3.57, 0.266, -2.05), Vector3(0, -90, 0), 0.78)
	_asset(root, "Radio", "res://open_assets/vintage_radio_transceiver/vintage_radio_transceiver.gltf", Vector3(0.66, 0.788, 0.78), Vector3(0, -28, 0), 0.82)
	_asset(root, "WineBottles", "res://open_assets/wine_bottles_01/wine_bottles_01.gltf", Vector3(0.76, 0.697, 1.03), Vector3(0, 18, 0), 0.8)
	_asset(root, "OilLamp", "res://open_assets/vintage_oil_lamp/vintage_oil_lamp.gltf", Vector3(2.55, 0.485, 2.02), Vector3(0, 0, 0), 0.62)
	_asset(root, "GothicStatue", "res://open_assets/gothic_statue/gothic_statue.gltf", Vector3(-3.55, 0.42, -3.3), Vector3(0, 28, 0), 0.34)
	_asset(root, "GasMask", "res://open_assets/old_gas_mask/old_gas_mask.gltf", Vector3(1.7, 1.9, -3.75), Vector3(0, 0, 0), 0.62)
	_asset(root, "WallMirror", "res://open_assets/ornate_mirror_01/ornate_mirror_01.gltf", Vector3(3.86, 1.95, 0.65), Vector3(0, -90, 0), 1.0)

	var mirror_probe := ReflectionProbe.new()
	mirror_probe.name = "MirrorProbe"
	mirror_probe.position = Vector3(3.1, 1.65, 0.65)
	mirror_probe.size = Vector3(2.0, 2.2, 2.4)
	mirror_probe.box_projection = true
	mirror_probe.update_mode = ReflectionProbe.UPDATE_ONCE
	root.add_child(mirror_probe)

	_omni(root, "LampLight", Vector3(2.55, 0.98, 2.02), "#ffb469", 1.65, 4.6, true)
	_sphere(root, "LampGlow", 0.035, Vector3(2.55, 0.96, 2.02), _mat("#ffb469", 0.2, 0.0, "#ffb469", 4.0))

	# Door on the back wall
	_box(root, "DoorFrameL", Vector3(0.14, 2.24, 0.16), Vector3(-0.67, 1.12, -3.87), wood_dark)
	_box(root, "DoorFrameR", Vector3(0.14, 2.24, 0.16), Vector3(0.67, 1.12, -3.87), wood_dark)
	_box(root, "DoorFrameTop", Vector3(1.48, 0.14, 0.16), Vector3(0.0, 2.24, -3.87), wood_dark)
	var hinge := Node3D.new()
	hinge.name = "DoorHinge"
	hinge.position = Vector3(-0.56, 0.0, -3.82)
	root.add_child(hinge)
	_box(hinge, "DoorSlab", Vector3(1.12, 2.16, 0.08), Vector3(0.56, 1.1, 0.0), wood)
	_box(hinge, "DoorPanelA", Vector3(0.42, 0.76, 0.025), Vector3(0.29, 1.58, 0.055), wood_dark)
	_box(hinge, "DoorPanelB", Vector3(0.42, 0.76, 0.025), Vector3(0.83, 1.58, 0.055), wood_dark)
	_box(hinge, "DoorPanelC", Vector3(0.42, 0.76, 0.025), Vector3(0.29, 0.72, 0.055), wood_dark)
	_box(hinge, "DoorPanelD", Vector3(0.42, 0.76, 0.025), Vector3(0.83, 0.72, 0.055), wood_dark)
	_cyl(hinge, "DoorHandle", 0.035, 0.1, Vector3(1.0, 1.05, 0.07), metal, Vector3(90, 0, 0))
	_cyl(hinge, "DoorHandleRose", 0.055, 0.025, Vector3(1.0, 1.05, 0.045), metal_dark, Vector3(90, 0, 0))
	_box(root, "DoorChain", Vector3(0.09, 0.025, 0.02), Vector3(0.22, 1.3, -3.76), metal)
	_box(root, "DoorChain2", Vector3(0.09, 0.025, 0.02), Vector3(0.15, 1.26, -3.76), metal, Vector3(0, 0, -22))
	# Blood at the handle: story in one detail
	_sphere(hinge, "BloodSmear", 0.09, Vector3(0.92, 0.98, 0.065), blood)
	_box(hinge, "BloodFinger1", Vector3(0.035, 0.12, 0.012), Vector3(0.86, 1.08, 0.065), blood, Vector3(0, 0, -8))
	_box(hinge, "BloodFinger2", Vector3(0.03, 0.1, 0.012), Vector3(0.92, 1.1, 0.065), blood)
	_box(hinge, "BloodFinger3", Vector3(0.028, 0.09, 0.012), Vector3(0.98, 1.09, 0.065), blood, Vector3(0, 0, 7))
	_box(root, "DoorGlow", Vector3(1.02, 0.015, 0.02), Vector3(0.0, 0.035, -3.79), _mat("#223322", 0.5, 0.0, "#7fa06a", 1.5))
	_omni(root, "DoorGlowLight", Vector3(0.0, 0.28, -3.5), "#8fb378", 0.95, 2.8, false)

	var door_ap := AnimationPlayer.new()
	door_ap.name = "DoorAnim"
	door_ap.root_node = NodePath("..")
	root.add_child(door_ap)
	var door_lib := AnimationLibrary.new()
	var door_knock := _anim_base("door_knock", 3.0, false)
	_track(door_knock, "DoorHinge:rotation_degrees", [[0.0, Vector3.ZERO], [0.15, Vector3.ZERO], [0.22, Vector3(0, -2.4, 0)], [0.29, Vector3(0, 0.7, 0)], [0.38, Vector3.ZERO], [1.9, Vector3.ZERO], [1.97, Vector3(0, -1.8, 0)], [2.04, Vector3(0, 0.5, 0)], [2.14, Vector3.ZERO], [3.0, Vector3.ZERO]])
	var door_open := _anim_base("door_open", 2.2, false)
	_track(door_open, "DoorHinge:rotation_degrees", [[0.0, Vector3.ZERO], [0.25, Vector3.ZERO], [1.35, Vector3(0, -82, 0)], [2.2, Vector3(0, -82, 0)]])
	var door_rattle := _anim_base("door_rattle", 4.8, false)
	_track(door_rattle, "DoorHinge:rotation_degrees", [[0.0, Vector3.ZERO], [2.62, Vector3.ZERO], [2.7, Vector3(0, -3.5, 0)], [2.77, Vector3(0, 1.2, 0)], [2.86, Vector3(0, -2.4, 0)], [2.95, Vector3(0, 0.8, 0)], [3.05, Vector3(0, -1.2, 0)], [3.2, Vector3.ZERO], [4.8, Vector3.ZERO]])
	door_lib.add_animation("door_knock", door_knock)
	door_lib.add_animation("door_open", door_open)
	door_lib.add_animation("door_rattle", door_rattle)
	door_ap.add_animation_library("", door_lib)

	# Wall art left of the door
	_box(root, "FrameA", Vector3(0.72, 0.56, 0.04), Vector3(-2.35, 2.06, -3.88), wood_dark)
	_box(root, "FrameAArt", Vector3(0.6, 0.44, 0.015), Vector3(-2.35, 2.06, -3.85), _mat("#3d3a30", 0.95))
	_box(root, "FrameB", Vector3(0.5, 0.68, 0.04), Vector3(-2.45, 1.18, -3.88), wood_dark)
	_box(root, "FrameBArt", Vector3(0.38, 0.56, 0.015), Vector3(-2.45, 1.18, -3.85), _mat("#4a3a32", 0.95))

	# Wall clock above the door
	_cyl(root, "ClockBody", 0.22, 0.055, Vector3(0.0, 2.72, -3.86), metal_dark, Vector3(90, 0, 0))
	_cyl(root, "ClockFace", 0.18, 0.01, Vector3(0.0, 2.72, -3.825), paper, Vector3(90, 0, 0))
	_box(root, "ClockHandH", Vector3(0.015, 0.09, 0.008), Vector3(0.0, 2.76, -3.815), black)
	_box(root, "ClockHandM", Vector3(0.012, 0.13, 0.008), Vector3(0.03, 2.71, -3.815), black, Vector3(0, 0, -52))

	# Window on the left wall
	_box(root, "WindowGlow", Vector3(0.03, 1.25, 1.45), Vector3(-3.9, 1.75, 0.8), _mat("#6f91b5", 0.5, 0.0, "#7b9ec4", 1.35))
	_box(root, "WindowFrameTop", Vector3(0.1, 0.1, 1.65), Vector3(-3.84, 2.42, 0.8), wood_dark)
	_box(root, "WindowFrameBottom", Vector3(0.1, 0.1, 1.65), Vector3(-3.84, 1.08, 0.8), wood_dark)
	_box(root, "WindowFrameLeft", Vector3(0.1, 1.44, 0.1), Vector3(-3.84, 1.75, 0.0), wood_dark)
	_box(root, "WindowFrameRight", Vector3(0.1, 1.44, 0.1), Vector3(-3.84, 1.75, 1.6), wood_dark)
	_box(root, "WindowBarV", Vector3(0.06, 1.34, 0.05), Vector3(-3.83, 1.75, 0.8), metal_dark)
	_box(root, "WindowBarH", Vector3(0.06, 0.05, 1.5), Vector3(-3.83, 1.75, 0.8), metal_dark)
	_cyl(root, "CurtainRod", 0.018, 2.0, Vector3(-3.78, 2.6, 0.8), metal, Vector3(90, 0, 0))
	_box(root, "CurtainL", Vector3(0.06, 1.65, 0.42), Vector3(-3.77, 1.72, -0.05), _mat("#3a1b1e", 0.98))
	_box(root, "CurtainR", Vector3(0.06, 1.65, 0.42), Vector3(-3.77, 1.72, 1.65), _mat("#3a1b1e", 0.98))

	var shadow_mat := _mat("#020305", 0.95)
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.albedo_color = Color(0.01, 0.015, 0.025, 0.62)
	var figure := Node3D.new()
	figure.name = "WindowShadow"
	figure.position = Vector3(-3.84, 2.1, 1.08)
	figure.rotation_degrees = Vector3(0, 90, 0)
	figure.scale = Vector3(0.78, 0.78, 0.78)
	root.add_child(figure)
	var f_head := _sphere(figure, "Head", 0.14, Vector3(0, -0.24, 0), shadow_mat)
	f_head.scale = Vector3(0.88, 1.12, 0.48)
	_box(figure, "Neck", Vector3(0.1, 0.12, 0.08), Vector3(0, -0.39, 0), shadow_mat)
	_box(figure, "Shoulders", Vector3(0.55, 0.13, 0.1), Vector3(0, -0.49, 0), shadow_mat)
	_box(figure, "Torso", Vector3(0.4, 0.66, 0.1), Vector3(0, -0.85, 0), shadow_mat)
	_box(figure, "ArmL", Vector3(0.085, 0.56, 0.08), Vector3(-0.25, -0.9, 0), shadow_mat, Vector3(0, 0, 6))
	_box(figure, "ArmR", Vector3(0.085, 0.56, 0.08), Vector3(0.25, -0.9, 0), shadow_mat, Vector3(0, 0, -6))
	_box(figure, "LegL", Vector3(0.12, 0.6, 0.09), Vector3(-0.1, -1.44, 0), shadow_mat)
	_box(figure, "LegR", Vector3(0.12, 0.6, 0.09), Vector3(0.1, -1.44, 0), shadow_mat)

	var moon := _spot(root, "MoonSpot", Vector3(-3.25, 2.35, 0.8), Vector3(1.6, 0.2, 0.2), "#6f8fb8", 3.4, 11.0, 44.0)
	moon.light_volumetric_fog_energy = 1.35
	_spot(root, "RimSpot", Vector3(-2.8, 2.25, -1.35), Vector3(0.0, 1.2, -3.5), "#7699c7", 3.4, 9.5, 34.0)
	_spot(root, "NeighborKey", Vector3(0.55, 2.15, -4.55), Vector3(-0.15, -0.35, 1.0), "#c7b8a6", 1.6, 6.0, 40.0)
	_omni(root, "NeighborFillLight", Vector3(0.0, 1.75, -2.55), "#b8a58f", 1.0, 5.0, false)
	_omni(root, "WindowFill", Vector3(-3.2, 2.0, 0.8), "#55789e", 0.8, 4.4, false)
	_omni(root, "RoomFill", Vector3(0.4, 2.55, 1.2), "#b79a76", 0.34, 8.0, false)

	# Ceiling fixture (off, but it gives the room a center line)
	_cyl(root, "Cord", 0.008, 0.55, Vector3(0.0, 2.95, 0.0), black)
	_sphere(root, "Bulb", 0.07, Vector3(0.0, 2.64, 0.0), _mat("#3a3528", 0.5, 0.0, "#7a6a3a", 0.15))

	# Dust motes, caught in the window light
	var dust := GPUParticles3D.new()
	dust.name = "DustMotes"
	dust.position = Vector3(0.0, 1.8, 0.0)
	dust.amount = 150
	dust.lifetime = 14.0
	dust.preprocess = 7.0
	dust.visibility_aabb = AABB(Vector3(-5, -2, -5), Vector3(10, 7, 10))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(3.2, 1.5, 3.2)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.01
	pm.initial_velocity_max = 0.06
	pm.gravity = Vector3(0.008, -0.006, 0.0)
	pm.scale_min = 0.45
	pm.scale_max = 1.2
	pm.color = Color(0.8, 0.86, 1.0, 0.34)
	dust.process_material = pm
	var dust_mesh := SphereMesh.new()
	dust_mesh.radius = 0.009
	dust_mesh.height = 0.018
	var dm := StandardMaterial3D.new()
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.vertex_color_use_as_albedo = true
	dm.albedo_color = Color(0.8, 0.86, 1.0, 0.42)
	dust_mesh.material = dm
	dust.draw_pass_1 = dust_mesh
	root.add_child(dust)

	var ambient_ap := AnimationPlayer.new()
	ambient_ap.name = "AmbientAnim"
	ambient_ap.root_node = NodePath("..")
	root.add_child(ambient_ap)
	var ambient_lib := AnimationLibrary.new()
	var ambient := _anim_base("ambient", 6.0, true)
	_track(ambient, "LampLight:light_energy", [[0.0, 1.15], [1.6, 1.35], [2.2, 1.02], [3.7, 1.28], [4.4, 1.1], [6.0, 1.15]])
	_track(ambient, "MoonSpot:light_energy", [[0.0, 3.4], [3.1, 3.4], [3.18, 4.7], [3.4, 3.4], [6.0, 3.4]])
	_track(ambient, "DoorGlowLight:light_energy", [[0.0, 0.65], [2.8, 0.5], [4.5, 0.72], [6.0, 0.65]])
	_track(ambient, "WindowShadow:position", [[0.0, Vector3(-3.86, 1.95, 0.85)], [2.2, Vector3(-3.86, 1.95, 0.78)], [3.2, Vector3(-3.86, 1.95, 0.9)], [4.6, Vector3(-3.86, 1.93, 0.84)], [6.0, Vector3(-3.86, 1.95, 0.85)]])
	_track(ambient, "WindowShadow:rotation_degrees", [[0.0, Vector3(0, 90, 0)], [2.2, Vector3(0, 95, 1.5)], [3.2, Vector3(0, 87, -1.0)], [6.0, Vector3(0, 90, 0)]])
	ambient_lib.add_animation("ambient", ambient)
	ambient_ap.add_animation_library("", ambient_lib)
	ambient_ap.autoplay = "ambient"

	# Anchors and slots
	var anchors := Node3D.new()
	anchors.name = "Anchors"
	root.add_child(anchors)
	_marker(anchors, "room_wide", Vector3(-2.55, 1.62, 2.9), Vector3(0.45, 1.1, -2.5))
	_marker(anchors, "door_pov", Vector3(0.0, 1.58, -1.9), Vector3(0.0, 1.3, -3.8))
	_marker(anchors, "door_medium", Vector3(0.0, 1.42, -0.7), Vector3(0.0, 1.3, -3.8))
	_marker(anchors, "door_close", Vector3(0.0, 1.45, -2.8), Vector3(0.0, 1.35, -3.82))
	_marker(anchors, "window", Vector3(-2.1, 1.68, 0.8), Vector3(-3.86, 1.72, 0.8))
	_marker(anchors, "table_detail", Vector3(1.62, 1.2, 1.85), Vector3(0.7, 0.76, 0.75))
	_marker(anchors, "table_center", Vector3(0.7, 0.72, 0.75))
	_marker(anchors, "lamp", Vector3(2.55, 0.95, 2.02))
	_marker(anchors, "low_corner", Vector3(-2.55, 0.66, 2.75), Vector3(0.45, 1.1, -2.8))
	_marker(anchors, "door", Vector3(0.0, 1.2, -3.8))
	_marker(anchors, "window_light", Vector3(-3.86, 1.72, 0.8))

	var slots := Node3D.new()
	slots.name = "Slots"
	root.add_child(slots)
	_marker(slots, "neighbor", Vector3(0.0, 0.0, -3.42), Vector3(0.0, 1.2, 0.0))
	_marker(slots, "player", Vector3(0.0, 0.0, 1.2), Vector3(0.0, 1.2, -3.8))

	_save(root, OUT + "/locations/room_night.tscn")


# --------------------------------------------------------------------------
# Characters
# --------------------------------------------------------------------------

func _build_human(id: String, is_zombie: bool) -> void:
	var root := Node3D.new()
	root.name = "Zombie" if is_zombie else "Survivor"

	var skin := _mat("#7f8f70" if is_zombie else "#b98d72", 0.74)
	var skin_dark := _mat("#5b6652" if is_zombie else "#8d6551", 0.8)
	var coat := _mat("#2a3129" if is_zombie else "#4a3426", 0.96)
	var coat_dark := _mat("#1b211c" if is_zombie else "#32231a", 0.98)
	var shirt := _mat("#6b6a5d" if is_zombie else "#7d7462", 0.94)
	var pants := _mat("#20252a" if is_zombie else "#2c3540", 0.95)
	var shoe := _mat("#111212", 0.9)
	var blood := _mat("#3d0a0a", 0.5)
	var eye := _mat("#c8d8b0", 0.3, 0.0, "#c8d8b0", 1.5)
	var hair := _mat("#241b16", 0.95)

	var hips := Node3D.new()
	hips.name = "Hips"
	hips.position = Vector3(0.0, 0.82, 0.0)
	root.add_child(hips)
	_box(hips, "Pelvis", Vector3(0.38, 0.22, 0.27), Vector3.ZERO, pants)
	_box(hips, "Belt", Vector3(0.4, 0.055, 0.29), Vector3(0.0, 0.09, 0.0), coat_dark)
	_box(hips, "Buckle", Vector3(0.06, 0.045, 0.02), Vector3(0.0, 0.09, -0.155), _mat("#8b7d5f", 0.4, 0.8))

	var torso := Node3D.new()
	torso.name = "Torso"
	torso.position = Vector3(0.0, 0.18, 0.0)
	torso.rotation_degrees = Vector3(8 if is_zombie else 0, 0, 0)
	hips.add_child(torso)
	_box(torso, "TorsoMesh", Vector3(0.44, 0.64, 0.29), Vector3(0.0, 0.32, 0.0), coat)
	_box(torso, "ShirtFront", Vector3(0.28, 0.45, 0.015), Vector3(0.0, 0.34, -0.153), shirt)
	_box(torso, "LapelL", Vector3(0.08, 0.3, 0.02), Vector3(-0.13, 0.46, -0.168), coat_dark, Vector3(0, 0, -11))
	_box(torso, "LapelR", Vector3(0.08, 0.3, 0.02), Vector3(0.13, 0.46, -0.168), coat_dark, Vector3(0, 0, 11))
	for i in range(3):
		_sphere(torso, "Button", 0.014, Vector3(0.0, 0.16 + float(i) * 0.12, -0.174), _mat("#8b7d5f", 0.35, 0.7))
	_box(torso, "CollarL", Vector3(0.13, 0.08, 0.04), Vector3(-0.08, 0.65, -0.12), coat_dark, Vector3(0, 0, -18))
	_box(torso, "CollarR", Vector3(0.13, 0.08, 0.04), Vector3(0.08, 0.65, -0.12), coat_dark, Vector3(0, 0, 18))
	_sphere(torso, "ShoulderL", 0.082, Vector3(-0.25, 0.6, 0.0), coat)
	_sphere(torso, "ShoulderR", 0.082, Vector3(0.25, 0.6, 0.0), coat)
	_cyl(torso, "Neck", 0.07, 0.14, Vector3(0.0, 0.69, -0.01), skin_dark)

	if is_zombie:
		for i in range(3):
			_box(torso, "Rib", Vector3(0.15, 0.025, 0.012), Vector3(-0.08, 0.2 + float(i) * 0.07, -0.162), skin, Vector3(0, 0, 4))
		var tear := _sphere(torso, "CoatTear", 0.09, Vector3(0.14, 0.18, -0.15), skin_dark)
		tear.scale = Vector3(1.1, 1.4, 0.25)

	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, 0.8, -0.01)
	head.rotation_degrees = Vector3(7 if is_zombie else 0, 0, 0)
	torso.add_child(head)
	var head_mesh := _sphere(head, "HeadMesh", 0.15, Vector3.ZERO, skin)
	head_mesh.scale = Vector3(0.82, 1.08, 0.9)
	_box(head, "Nose", Vector3(0.035, 0.055, 0.04), Vector3(0.0, -0.008, -0.145), skin_dark)
	_sphere(head, "EyeL", 0.016, Vector3(-0.052, 0.035, -0.132), eye)
	_sphere(head, "EyeR", 0.016, Vector3(0.052, 0.035, -0.132), eye)
	_box(head, "BrowL", Vector3(0.058, 0.015, 0.018), Vector3(-0.052, 0.07, -0.133), coat_dark, Vector3(0, 0, -8))
	_box(head, "BrowR", Vector3(0.058, 0.015, 0.018), Vector3(0.052, 0.07, -0.133), coat_dark, Vector3(0, 0, 8))
	_sphere(head, "EarL", 0.03, Vector3(-0.13, 0.0, 0.0), skin_dark)
	_sphere(head, "EarR", 0.03, Vector3(0.13, 0.0, 0.0), skin_dark)
	var jaw := Node3D.new()
	jaw.name = "Jaw"
	jaw.position = Vector3(0.0, -0.075, -0.03)
	head.add_child(jaw)
	_box(jaw, "JawMesh", Vector3(0.13, 0.06, 0.12), Vector3(0.0, -0.03, -0.05), skin_dark)
	_box(jaw, "Mouth", Vector3(0.08, 0.018, 0.018), Vector3(0.0, -0.005, -0.108), _mat("#160809", 0.9))

	if is_zombie:
		var mouth_blood := _sphere(jaw, "MouthBlood", 0.03, Vector3(0.015, -0.035, -0.108), blood)
		mouth_blood.scale = Vector3(1.3, 0.6, 0.3)
		var stain_a := _sphere(torso, "BloodStainA", 0.09, Vector3(0.08, 0.34, -0.15), blood)
		stain_a.scale = Vector3(0.8, 1.5, 0.2)
		var stain_b := _sphere(torso, "BloodStainB", 0.07, Vector3(-0.11, 0.12, -0.14), blood)
		stain_b.scale = Vector3(1.2, 0.7, 0.2)
		var stain_c := _sphere(head, "BloodStainC", 0.038, Vector3(0.1, 0.045, -0.112), blood)
		stain_c.scale = Vector3(0.8, 0.8, 0.2)
	else:
		var cap := _sphere(head, "Hair", 0.152, Vector3(0.0, 0.04, 0.015), hair)
		cap.scale = Vector3(0.9, 0.78, 0.94)
		_box(head, "Fringe", Vector3(0.22, 0.06, 0.1), Vector3(0.0, 0.1, -0.1), hair, Vector3(-12, 0, 0))

	for side in [-1, 1]:
		var arm := Node3D.new()
		arm.name = "ArmL" if side < 0 else "ArmR"
		arm.position = Vector3(0.31 * side, 0.58, 0.0)
		arm.rotation_degrees = Vector3(55 if is_zombie else 0, 0, 8 if side < 0 else -8)
		torso.add_child(arm)
		_cyl(arm, "UpperArm", 0.078, 0.34, Vector3(0.0, -0.17, 0.0), coat)
		var elbow := Node3D.new()
		elbow.name = "ElbowL" if side < 0 else "ElbowR"
		elbow.position = Vector3(0.0, -0.34, 0.0)
		elbow.rotation_degrees = Vector3(12 if is_zombie else 0, 0, 0)
		arm.add_child(elbow)
		_cyl(elbow, "Forearm", 0.064, 0.31, Vector3(0.0, -0.155, 0.0), skin if is_zombie else coat)
		_sphere(elbow, "ElbowCap", 0.073, Vector3.ZERO, coat_dark)
		_sphere(elbow, "Hand", 0.061, Vector3(0.0, -0.33, 0.0), skin)
		if is_zombie:
			_box(elbow, "WristBlood", Vector3(0.078, 0.03, 0.08), Vector3(0.0, -0.275, 0.0), blood)
			for f in range(3):
				_box(elbow, "Finger", Vector3(0.014, 0.05, 0.014), Vector3(-0.03 + float(f) * 0.03, -0.38, -0.018), skin_dark)

	for side in [-1, 1]:
		var leg := Node3D.new()
		leg.name = "LegL" if side < 0 else "LegR"
		leg.position = Vector3(0.14 * side, 0.82, 0.0)
		root.add_child(leg)
		_cyl(leg, "Thigh", 0.095, 0.38, Vector3(0.0, -0.19, 0.0), pants)
		var knee := Node3D.new()
		knee.name = "KneeL" if side < 0 else "KneeR"
		knee.position = Vector3(0.0, -0.38, 0.0)
		leg.add_child(knee)
		_cyl(knee, "Shin", 0.078, 0.34, Vector3(0.0, -0.17, 0.0), pants)
		_sphere(knee, "KneeCap", 0.082, Vector3.ZERO, pants)
		_box(knee, "Foot", Vector3(0.19, 0.1, 0.32), Vector3(0.0, -0.36, -0.09), shoe)

	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	ap.root_node = NodePath("..")
	root.add_child(ap)
	var lib := AnimationLibrary.new()
	lib.add_animation("idle", _anim_idle(is_zombie))
	lib.add_animation("walk", _anim_walk(is_zombie))
	if is_zombie:
		lib.add_animation("knock", _anim_knock())
		lib.add_animation("lurch", _anim_lurch())
		lib.add_animation("attack", _anim_attack())
	ap.add_animation_library("", lib)

	if not is_zombie:
		root.scale = Vector3(0.95, 0.95, 0.95)

	_save(root, OUT + "/characters/" + id + ".tscn")


func _anim_base(anim_name: String, length: float, loop: bool) -> Animation:
	var a := Animation.new()
	a.resource_name = anim_name
	a.length = length
	a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	a.step = 0.01
	return a


func _track(a: Animation, path: String, keys: Array) -> void:
	var idx := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(idx, NodePath(path))
	for k in keys:
		a.track_insert_key(idx, float(k[0]), k[1])


func _anim_idle(is_zombie: bool) -> Animation:
	var a := _anim_base("idle", 4.0, true)
	var lean := 8.0 if is_zombie else 1.0
	var head_lean := 7.0 if is_zombie else 0.0
	var arm_x := 55.0 if is_zombie else 0.0
	var arm_r_x := 50.0 if is_zombie else 0.0
	_track(a, "Hips:position", [[0.0, Vector3(0, 0.82, 0)], [2.0, Vector3(0, 0.827, 0)], [4.0, Vector3(0, 0.82, 0)]])
	_track(a, "Hips:rotation_degrees", [[0.0, Vector3(0, 0, 0)], [2.0, Vector3(0, -1.5, -1.0)], [4.0, Vector3(0, 0, 0)]])
	_track(a, "Hips/Torso:rotation_degrees", [[0.0, Vector3(lean, 0, -1.0)], [1.4, Vector3(lean + 2.0, 2.0, -2.0)], [2.8, Vector3(lean - 1.0, -2.0, 0.0)], [4.0, Vector3(lean, 0, -1.0)]])
	_track(a, "Hips/Torso/Head:rotation_degrees", [[0.0, Vector3(head_lean, 0, 2.0)], [0.8, Vector3(head_lean + 2.0, 9.0, 3.0)], [1.7, Vector3(head_lean - 1.0, -7.0, -2.0)], [2.7, Vector3(head_lean + 3.0, 3.0, 5.0)], [3.3, Vector3(head_lean - 2.0, -4.0, -4.0)], [4.0, Vector3(head_lean, 0, 2.0)]])
	_track(a, "Hips/Torso/Head/Jaw:rotation_degrees", [[0.0, Vector3.ZERO], [3.0, Vector3.ZERO], [3.08, Vector3(6, 0, 0)], [3.16, Vector3.ZERO], [4.0, Vector3.ZERO]])
	_track(a, "Hips/Torso/ArmL:rotation_degrees", [[0.0, Vector3(arm_x, 0, 8)], [2.0, Vector3(arm_x + 3.0, 0, 6)], [4.0, Vector3(arm_x, 0, 8)]])
	_track(a, "Hips/Torso/ArmL/ElbowL:rotation_degrees", [[0.0, Vector3(12 if is_zombie else 0, 0, 0)], [2.0, Vector3(18 if is_zombie else 2, 0, 0)], [4.0, Vector3(12 if is_zombie else 0, 0, 0)]])
	_track(a, "Hips/Torso/ArmR:rotation_degrees", [[0.0, Vector3(arm_r_x, 0, -8)], [2.0, Vector3(arm_r_x + 3.0, 0, -6)], [4.0, Vector3(arm_r_x, 0, -8)]])
	_track(a, "Hips/Torso/ArmR/ElbowR:rotation_degrees", [[0.0, Vector3(10 if is_zombie else 0, 0, 0)], [2.0, Vector3(15 if is_zombie else -2, 0, 0)], [4.0, Vector3(10 if is_zombie else 0, 0, 0)]])
	return a


func _anim_walk(is_zombie: bool) -> Animation:
	var a := _anim_base("walk", 1.15, true)
	var lean := 10.0 if is_zombie else 2.0
	var arm_x := 48.0 if is_zombie else 0.0
	_track(a, "Hips:position", [[0.0, Vector3(0, 0.82, 0)], [0.29, Vector3(0, 0.842, 0)], [0.575, Vector3(0, 0.82, 0)], [0.86, Vector3(0, 0.84, 0)], [1.15, Vector3(0, 0.82, 0)]])
	_track(a, "Hips/Torso:rotation_degrees", [[0.0, Vector3(lean, 0, 3 if is_zombie else 0)], [0.575, Vector3(lean, 0, -3 if is_zombie else 0)], [1.15, Vector3(lean, 0, 3 if is_zombie else 0)]])
	_track(a, "Hips/Torso/Head:rotation_degrees", [[0.0, Vector3(10 if is_zombie else 0, 0, -4)], [0.575, Vector3(10 if is_zombie else 0, 0, 4)], [1.15, Vector3(10 if is_zombie else 0, 0, -4)]])
	_track(a, "LegL:rotation_degrees", [[0.0, Vector3(24, 0, 0)], [0.575, Vector3(-24, 0, 0)], [1.15, Vector3(24, 0, 0)]])
	_track(a, "LegL/KneeL:rotation_degrees", [[0.0, Vector3(4, 0, 0)], [0.29, Vector3(20, 0, 0)], [0.575, Vector3(2, 0, 0)], [1.15, Vector3(4, 0, 0)]])
	_track(a, "LegR:rotation_degrees", [[0.0, Vector3(-24, 0, 0)], [0.575, Vector3(24, 0, 0)], [1.15, Vector3(-24, 0, 0)]])
	_track(a, "LegR/KneeR:rotation_degrees", [[0.0, Vector3(2, 0, 0)], [0.29, Vector3(4, 0, 0)], [0.86, Vector3(20, 0, 0)], [1.15, Vector3(2, 0, 0)]])
	_track(a, "Hips/Torso/ArmL:rotation_degrees", [[0.0, Vector3(arm_x - 10 if is_zombie else -20, 0, 8)], [0.575, Vector3(arm_x + 10 if is_zombie else 20, 0, 8)], [1.15, Vector3(arm_x - 10 if is_zombie else -20, 0, 8)]])
	_track(a, "Hips/Torso/ArmL/ElbowL:rotation_degrees", [[0.0, Vector3(10, 0, 0)], [0.575, Vector3(24 if is_zombie else 16, 0, 0)], [1.15, Vector3(10, 0, 0)]])
	_track(a, "Hips/Torso/ArmR:rotation_degrees", [[0.0, Vector3(arm_x + 10 if is_zombie else 20, 0, -8)], [0.575, Vector3(arm_x - 10 if is_zombie else -20, 0, -8)], [1.15, Vector3(arm_x + 10 if is_zombie else 20, 0, -8)]])
	_track(a, "Hips/Torso/ArmR/ElbowR:rotation_degrees", [[0.0, Vector3(24 if is_zombie else 16, 0, 0)], [0.575, Vector3(10, 0, 0)], [1.15, Vector3(24 if is_zombie else 16, 0, 0)]])
	return a


func _anim_knock() -> Animation:
	var a := _anim_base("knock", 4.8, false)
	_track(a, "Hips:position", [[0.0, Vector3(0, 0.82, 0)], [0.28, Vector3(0, 0.805, -0.03)], [0.48, Vector3(0, 0.82, 0)], [1.4, Vector3(0, 0.807, -0.025)], [1.7, Vector3(0, 0.82, 0)], [2.2, Vector3(0, 0.82, 0)], [4.8, Vector3(0, 0.82, 0)]])
	_track(a, "Hips/Torso:rotation_degrees", [[0.0, Vector3(8, 0, -1)], [0.3, Vector3(12, -3, -2)], [0.48, Vector3(7, 2, 1)], [1.45, Vector3(12, 3, 2)], [1.7, Vector3(8, 0, -1)], [2.2, Vector3(8, 0, -1)], [2.7, Vector3(10, 2, 0)], [3.4, Vector3(8, -2, -1)], [4.8, Vector3(8, 0, -1)]])
	_track(a, "Hips/Torso/Head:rotation_degrees", [[0.0, Vector3(7, 0, 2)], [0.3, Vector3(9, 3, 4)], [0.7, Vector3(6, -4, -2)], [1.5, Vector3(10, 4, 5)], [1.9, Vector3(7, 0, 2)], [2.2, Vector3(6, 0, 2)], [2.8, Vector3(4, 8, 1)], [3.5, Vector3(8, -7, 3)], [4.2, Vector3(5, 4, -2)], [4.8, Vector3(7, 0, 2)]])
	_track(a, "Hips/Torso/Head/Jaw:rotation_degrees", [[0.0, Vector3.ZERO], [2.1, Vector3.ZERO], [2.25, Vector3(11, 0, 0)], [2.4, Vector3(2, 0, 0)], [2.65, Vector3(13, 0, 0)], [2.8, Vector3(3, 0, 0)], [3.2, Vector3(12, 0, 0)], [3.35, Vector3(2, 0, 0)], [3.7, Vector3(9, 0, 0)], [3.85, Vector3(0, 0, 0)], [4.8, Vector3.ZERO]])
	_track(a, "Hips/Torso/ArmR:rotation_degrees", [[0.0, Vector3(50, 0, -8)], [0.18, Vector3(76, 0, -10)], [0.32, Vector3(94, 0, -5)], [0.42, Vector3(63, 0, -12)], [0.55, Vector3(92, 0, -5)], [0.65, Vector3(60, 0, -12)], [1.15, Vector3(55, 0, -8)], [1.45, Vector3(90, 0, -5)], [1.58, Vector3(59, 0, -12)], [1.9, Vector3(55, 0, -8)], [4.8, Vector3(55, 0, -8)]])
	_track(a, "Hips/Torso/ArmR/ElbowR:rotation_degrees", [[0.0, Vector3(10, 0, 0)], [0.18, Vector3(38, 0, 0)], [0.32, Vector3(4, 0, 0)], [0.42, Vector3(40, 0, 0)], [0.55, Vector3(6, 0, 0)], [0.65, Vector3(38, 0, 0)], [1.15, Vector3(14, 0, 0)], [1.45, Vector3(4, 0, 0)], [1.58, Vector3(38, 0, 0)], [1.9, Vector3(12, 0, 0)], [4.8, Vector3(12, 0, 0)]])
	_track(a, "Hips/Torso/ArmL:rotation_degrees", [[0.0, Vector3(55, 0, 8)], [0.4, Vector3(64, 0, 12)], [1.7, Vector3(58, 0, 9)], [2.2, Vector3(55, 0, 8)], [4.8, Vector3(55, 0, 8)]])
	_track(a, "Hips/Torso/ArmL/ElbowL:rotation_degrees", [[0.0, Vector3(12, 0, 0)], [0.4, Vector3(20, 0, 0)], [1.7, Vector3(14, 0, 0)], [4.8, Vector3(12, 0, 0)]])
	_track(a, "LegL:rotation_degrees", [[0.0, Vector3(0, 0, 0)], [0.4, Vector3(4, 0, 0)], [1.7, Vector3(0, 0, 0)], [4.8, Vector3(0, 0, 0)]])
	return a


func _anim_lurch() -> Animation:
	var a := _anim_base("lurch", 4.6, false)
	_track(a, "Hips:position", [[0.0, Vector3(0, 0.82, 0)], [0.8, Vector3(0, 0.795, -0.06)], [1.6, Vector3(0, 0.8, -0.12)], [2.65, Vector3(0, 0.79, -0.08)], [2.8, Vector3(0, 0.81, -0.15)], [3.0, Vector3(0, 0.8, -0.1)], [4.6, Vector3(0, 0.82, -0.02)]])
	_track(a, "Hips:rotation_degrees", [[0.0, Vector3(0, 0, 0)], [1.6, Vector3(0, 4, -2)], [2.8, Vector3(0, -6, 3)], [4.6, Vector3(0, 0, 0)]])
	_track(a, "Hips/Torso:rotation_degrees", [[0.0, Vector3(8, 0, -1)], [0.7, Vector3(14, -4, 2)], [1.6, Vector3(19, 5, -3)], [2.65, Vector3(13, -2, 1)], [2.8, Vector3(22, 8, -5)], [3.15, Vector3(16, -4, 2)], [4.6, Vector3(10, 0, -1)]])
	_track(a, "Hips/Torso/Head:rotation_degrees", [[0.0, Vector3(7, 0, 2)], [0.8, Vector3(12, -8, 4)], [1.7, Vector3(4, 11, -4)], [2.6, Vector3(8, -5, 2)], [2.8, Vector3(23, 12, -8)], [3.1, Vector3(2, -9, 5)], [3.6, Vector3(9, 4, -2)], [4.6, Vector3(7, 0, 2)]])
	_track(a, "Hips/Torso/Head/Jaw:rotation_degrees", [[0.0, Vector3(4, 0, 0)], [1.2, Vector3(15, 0, 0)], [2.2, Vector3(3, 0, 0)], [2.8, Vector3(20, 0, 0)], [3.4, Vector3(2, 0, 0)], [4.6, Vector3(6, 0, 0)]])
	_track(a, "Hips/Torso/ArmL:rotation_degrees", [[0.0, Vector3(55, 0, 8)], [0.9, Vector3(82, 0, 15)], [1.7, Vector3(91, 0, 10)], [2.65, Vector3(76, 0, 18)], [2.8, Vector3(102, 0, 7)], [3.2, Vector3(84, 0, 13)], [4.6, Vector3(64, 0, 9)]])
	_track(a, "Hips/Torso/ArmL/ElbowL:rotation_degrees", [[0.0, Vector3(12, 0, 0)], [0.9, Vector3(26, 0, 0)], [1.7, Vector3(8, 0, 0)], [2.8, Vector3(20, 0, 0)], [3.2, Vector3(9, 0, 0)], [4.6, Vector3(18, 0, 0)]])
	_track(a, "Hips/Torso/ArmR:rotation_degrees", [[0.0, Vector3(50, 0, -8)], [0.9, Vector3(78, 0, -17)], [1.7, Vector3(92, 0, -9)], [2.65, Vector3(70, 0, -20)], [2.8, Vector3(101, 0, -6)], [3.2, Vector3(82, 0, -13)], [4.6, Vector3(61, 0, -9)]])
	_track(a, "Hips/Torso/ArmR/ElbowR:rotation_degrees", [[0.0, Vector3(10, 0, 0)], [0.9, Vector3(28, 0, 0)], [1.7, Vector3(7, 0, 0)], [2.8, Vector3(18, 0, 0)], [3.2, Vector3(8, 0, 0)], [4.6, Vector3(16, 0, 0)]])
	_track(a, "LegL:rotation_degrees", [[0.0, Vector3(0, 0, 0)], [0.9, Vector3(16, 0, 0)], [1.7, Vector3(4, 0, 0)], [2.8, Vector3(20, 0, 0)], [3.2, Vector3(7, 0, 0)], [4.6, Vector3(0, 0, 0)]])
	_track(a, "LegL/KneeL:rotation_degrees", [[0.0, Vector3(0, 0, 0)], [0.9, Vector3(22, 0, 0)], [1.7, Vector3(6, 0, 0)], [2.8, Vector3(26, 0, 0)], [3.2, Vector3(10, 0, 0)], [4.6, Vector3(0, 0, 0)]])
	_track(a, "LegR:rotation_degrees", [[0.0, Vector3(0, 0, 0)], [0.9, Vector3(-8, 0, 0)], [1.7, Vector3(7, 0, 0)], [2.8, Vector3(-10, 0, 0)], [3.2, Vector3(4, 0, 0)], [4.6, Vector3(0, 0, 0)]])
	_track(a, "LegR/KneeR:rotation_degrees", [[0.0, Vector3(0, 0, 0)], [0.9, Vector3(10, 0, 0)], [1.7, Vector3(4, 0, 0)], [2.8, Vector3(16, 0, 0)], [3.2, Vector3(6, 0, 0)], [4.6, Vector3(0, 0, 0)]])
	return a


func _anim_attack() -> Animation:
	var a := _anim_base("attack", 1.1, false)
	_track(a, "Hips/Torso/ArmL:rotation_degrees", [[0.0, Vector3(55, 0, 8)], [0.3, Vector3(108, 0, 22)], [0.65, Vector3(96, 0, 14)], [1.1, Vector3(66, 0, 10)]])
	_track(a, "Hips/Torso/ArmR:rotation_degrees", [[0.0, Vector3(50, 0, -8)], [0.3, Vector3(104, 0, -22)], [0.65, Vector3(94, 0, -14)], [1.1, Vector3(62, 0, -10)]])
	_track(a, "Hips:position", [[0.0, Vector3(0, 0.82, 0)], [0.35, Vector3(0, 0.79, -0.12)], [0.7, Vector3(0, 0.81, -0.05)], [1.1, Vector3(0, 0.82, 0)]])
	_track(a, "Hips/Torso:rotation_degrees", [[0.0, Vector3(8, 0, 0)], [0.35, Vector3(20, 0, 0)], [1.1, Vector3(9, 0, 0)]])
	_track(a, "Hips/Torso/Head:rotation_degrees", [[0.0, Vector3(7, 0, 0)], [0.35, Vector3(20, 0, 0)], [1.1, Vector3(7, 0, 0)]])
	return a


# --------------------------------------------------------------------------
# Props
# --------------------------------------------------------------------------

func _build_radio() -> void:
	var root := Node3D.new()
	root.name = "Radio"
	var plastic := _mat("#1d211f", 0.65)
	var panel := _mat("#0c0d0c", 0.6)
	var metal := _mat("#7a7870", 0.35, 0.7)
	var dial := _mat("#16251a", 0.4, 0.0, "#7fd18f", 1.4)
	_box(root, "Body", Vector3(0.36, 0.2, 0.18), Vector3(0, 0.1, 0), plastic)
	_box(root, "Panel", Vector3(0.3, 0.14, 0.02), Vector3(0, 0.1, -0.095), panel)
	_box(root, "Dial", Vector3(0.17, 0.025, 0.012), Vector3(0, 0.135, -0.108), dial)
	_cyl(root, "KnobL", 0.025, 0.02, Vector3(-0.1, 0.065, -0.108), metal, Vector3(90, 0, 0))
	_cyl(root, "KnobR", 0.025, 0.02, Vector3(0.1, 0.065, -0.108), metal, Vector3(90, 0, 0))
	_cyl(root, "Antenna", 0.006, 0.52, Vector3(0.13, 0.36, 0.02), metal, Vector3(0, 0, -12))
	_box(root, "Speaker", Vector3(0.14, 0.05, 0.005), Vector3(0, 0.06, -0.107), _mat("#2b2d29", 0.9))
	_save(root, OUT + "/props/radio.tscn")


func _build_door() -> void:
	var root := Node3D.new()
	root.name = "Door"
	var wood := _mat("#5a3d28", 0.72)
	var wood_dark := _mat("#3b281a", 0.8)
	var metal := _mat("#6b6a66", 0.34, 0.8)
	_box(root, "FrameL", Vector3(0.14, 2.24, 0.16), Vector3(-0.67, 1.12, 0), wood_dark)
	_box(root, "FrameR", Vector3(0.14, 2.24, 0.16), Vector3(0.67, 1.12, 0), wood_dark)
	_box(root, "FrameTop", Vector3(1.48, 0.14, 0.16), Vector3(0, 2.24, 0), wood_dark)
	var hinge := Node3D.new()
	hinge.name = "Hinge"
	hinge.position = Vector3(-0.55, 0.0, 0.0)
	root.add_child(hinge)
	_box(hinge, "Slab", Vector3(1.1, 2.16, 0.08), Vector3(0.55, 1.1, 0), wood)
	_box(hinge, "PanelA", Vector3(0.4, 0.76, 0.025), Vector3(0.28, 1.58, 0.055), wood_dark)
	_box(hinge, "PanelB", Vector3(0.4, 0.76, 0.025), Vector3(0.82, 1.58, 0.055), wood_dark)
	_box(hinge, "PanelC", Vector3(0.4, 0.76, 0.025), Vector3(0.28, 0.72, 0.055), wood_dark)
	_box(hinge, "PanelD", Vector3(0.4, 0.76, 0.025), Vector3(0.82, 0.72, 0.055), wood_dark)
	_cyl(hinge, "Handle", 0.035, 0.1, Vector3(0.98, 1.05, 0.06), metal, Vector3(90, 0, 0))
	_cyl(hinge, "HandleRose", 0.055, 0.025, Vector3(0.98, 1.05, 0.035), metal, Vector3(90, 0, 0))
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	ap.root_node = NodePath("..")
	root.add_child(ap)
	var lib := AnimationLibrary.new()
	var open := _anim_base("open", 1.2, false)
	_track(open, "Hinge:rotation_degrees", [[0.0, Vector3(0, 0, 0)], [1.2, Vector3(0, 96, 0)]])
	var close := _anim_base("close", 1.2, false)
	_track(close, "Hinge:rotation_degrees", [[0.0, Vector3(0, 96, 0)], [1.2, Vector3(0, 0, 0)]])
	lib.add_animation("open", open)
	lib.add_animation("close", close)
	ap.add_animation_library("", lib)
	_save(root, OUT + "/props/door.tscn")
