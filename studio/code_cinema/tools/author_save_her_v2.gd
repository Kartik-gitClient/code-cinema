extends SceneTree

const OUT := "res://kit/locations"
const PULSE := preload("res://code_cinema/tools/pulse_light.gd")
const PULSE_LABEL := preload("res://code_cinema/tools/pulse_label.gd")

var _cache := {}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_apartment()
	_street()
	_mart()
	print("Authored SAVE HER v2 sets")
	quit()


func _apartment() -> void:
	_cache.clear()
	var root := _root("ApartmentDawn")
	var wall := _mat(Color("#3f6b6a"), 0.88)
	var dark := _mat(Color("#2a4b52"), 0.9)
	var trim := _mat(Color("#e8d9b8"), 0.75)
	var wood := _mat(Color("#b56b3c"), 0.62)
	var fabric := _mat(Color("#e0a83e"), 0.94)
	var black := _mat(Color("#101416"), 0.4, 0.2)
	var metal := _mat(Color("#c9a86a"), 0.32, 0.72)
	var cream := _mat(Color("#f2e6cc"), 0.86)
	var coral := _mat(Color("#c94f3d"), 0.82)
	var ocean := _mat(Color("#2f7d9e"), 0.8)
	var pink := _mat(Color("#d96a8b"), 0.84)
	var leaf := _mat(Color("#3f8f4f"), 0.82)
	var lemon := _mat(Color("#f2b544"), 0.8)

	_box(root, "Floor", Vector3(5.6, 0.12, 5.2), Vector3(0, -0.06, 0), _mat(Color("#8a5a3a"), 0.7))
	_box(root, "Ceiling", Vector3(5.6, 0.1, 5.2), Vector3(0, 2.95, 0), dark)
	_box(root, "LeftLower", Vector3(0.12, 0.95, 5.2), Vector3(-2.8, 0.475, 0), wall)
	_box(root, "LeftUpper", Vector3(0.12, 0.4, 5.2), Vector3(-2.8, 2.75, 0), wall)
	_box(root, "LeftBack", Vector3(0.12, 1.6, 2.0), Vector3(-2.8, 1.75, -1.6), wall)
	_box(root, "LeftFront", Vector3(0.12, 1.6, 1.6), Vector3(-2.8, 1.75, 1.8), wall)
	_box(root, "RightWall", Vector3(0.12, 2.9, 5.2), Vector3(2.8, 1.45, 0), wall)
	_box(root, "FrontWall", Vector3(5.6, 2.9, 0.12), Vector3(0, 1.45, 2.6), wall)
	_box(root, "BackWall", Vector3(5.6, 2.9, 0.12), Vector3(0, 1.45, -2.6), dark)
	for x in [-2.72, 2.72]:
		_box(root, "BaseboardX", Vector3(0.05, 0.12, 5.1), Vector3(x, 0.06, 0), trim)
	for z in [-2.52, 2.52]:
		_box(root, "BaseboardZ", Vector3(5.5, 0.12, 0.05), Vector3(0, 0.06, z), trim)

	_box(root, "WindowTop", Vector3(0.16, 0.08, 1.72), Vector3(-2.8, 2.55, 0.2), trim)
	_box(root, "WindowBottom", Vector3(0.16, 0.08, 1.72), Vector3(-2.8, 0.95, 0.2), trim)
	for z in [-0.6, 1.0]:
		_box(root, "WindowSide", Vector3(0.16, 1.7, 0.08), Vector3(-2.8, 1.75, z), trim)
	_box(root, "WindowMullion", Vector3(0.12, 1.6, 0.05), Vector3(-2.8, 1.75, 0.2), trim)
	_quad(root, "Skyline", Vector2(6.5, 4.0), Vector3(-3.35, 1.75, 0.2), _texture_mat(_city_texture()), Vector3(0, 90, 0))
	_box(root, "WindowLedge", Vector3(0.45, 0.08, 1.9), Vector3(-3.0, 0.9, 0.2), trim)
	for z in [-0.8, 1.2]:
		_box(root, "Curtain", Vector3(0.08, 1.95, 0.32), Vector3(-2.63, 1.6, z), coral)
	_box(root, "Radiator", Vector3(0.18, 0.5, 1.8), Vector3(-2.64, 0.34, 0.2), metal)

	_box(root, "CounterBase", Vector3(0.6, 0.9, 2.6), Vector3(2.45, 0.45, -1.2), ocean)
	_box(root, "CounterTop", Vector3(0.66, 0.06, 2.7), Vector3(2.44, 0.93, -1.2), cream)
	_box(root, "UpperCabinet", Vector3(0.4, 0.72, 2.4), Vector3(2.56, 2.2, -1.2), cream)
	_box(root, "Fridge", Vector3(0.68, 1.82, 0.72), Vector3(2.4, 0.91, 1.65), coral)
	_box(root, "FridgeHandle", Vector3(0.03, 0.5, 0.03), Vector3(2.04, 1.1, 1.4), metal)
	_box(root, "Sink", Vector3(0.42, 0.05, 0.5), Vector3(2.42, 0.97, -0.3), black)
	_box(root, "Microwave", Vector3(0.46, 0.3, 0.36), Vector3(2.56, 1.46, 0.45), black)
	_label(root, "Clock", "08:12", Vector3(2.32, 1.46, 0.45), -90, 26, Color("#8fd9a8"), 5, 0.002, true, 8)
	_box(root, "Kettle", Vector3(0.18, 0.24, 0.18), Vector3(2.4, 1.08, -1.7), metal)
	for i in range(10):
		var tile_col = [ocean, cream, coral, lemon][i % 4]
		_box(root, "Backsplash", Vector3(0.04, 0.16, 0.18), Vector3(2.7, 1.18 + (i % 2) * 0.18, -2.25 + i * 0.22), tile_col)
	for i in range(4):
		var jar_col = [coral, lemon, ocean, pink][i]
		_cyl(root, "Jar", 0.07, 0.16, Vector3(2.36, 1.04, -2.05 + i * 0.25), jar_col)
	_box(root, "FridgeArt", Vector3(0.02, 0.26, 0.2), Vector3(2.04, 1.35, 1.55), lemon)
	_box(root, "FridgeArt2", Vector3(0.02, 0.18, 0.14), Vector3(2.04, 1.05, 1.78), ocean)

	_box(root, "Rug", Vector3(2.9, 0.02, 2.05), Vector3(0.1, 0.015, 0.55), coral)
	_box(root, "RugInner", Vector3(2.45, 0.025, 1.65), Vector3(0.1, 0.02, 0.55), lemon)
	_box(root, "RugStripe", Vector3(2.15, 0.03, 0.22), Vector3(0.1, 0.025, 0.55), ocean)
	_box(root, "RugStripe2", Vector3(0.22, 0.032, 1.45), Vector3(0.1, 0.028, 0.55), pink)
	_box(root, "SofaBase", Vector3(2.0, 0.42, 0.8), Vector3(-1.35, 0.25, -1.85), fabric)
	_box(root, "SofaBack", Vector3(2.0, 0.72, 0.2), Vector3(-1.35, 0.72, -2.2), fabric)
	for x in [-2.3, -0.4]:
		_box(root, "SofaArm", Vector3(0.2, 0.55, 0.8), Vector3(x, 0.38, -1.85), fabric)
	_box(root, "CushionCoral", Vector3(0.36, 0.36, 0.16), Vector3(-1.85, 0.56, -2.04), coral, Vector3(0, 0, 12))
	_box(root, "CushionOcean", Vector3(0.36, 0.36, 0.16), Vector3(-1.3, 0.56, -2.04), ocean, Vector3(0, 0, -9))
	_box(root, "CushionCream", Vector3(0.36, 0.36, 0.16), Vector3(-0.78, 0.56, -2.04), cream, Vector3(0, 0, 7))
	_box(root, "Throw", Vector3(0.62, 0.04, 0.5), Vector3(-2.0, 0.47, -1.8), pink, Vector3(0, 18, 0))
	_box(root, "CoffeeTable", Vector3(1.05, 0.06, 0.62), Vector3(0.65, 0.42, 1.05), wood)
	for x in [0.2, 1.1]:
		for z in [0.8, 1.3]:
			_box(root, "TableLeg", Vector3(0.05, 0.4, 0.05), Vector3(x, 0.2, z), trim)
	_box(root, "TableRunner", Vector3(0.7, 0.012, 0.24), Vector3(0.65, 0.455, 1.05), ocean)
	_cyl(root, "Mug", 0.05, 0.11, Vector3(0.45, 0.51, 1.0), _mat(Color("#b9b0a1"), 0.6))
	_box(root, "BookCoral", Vector3(0.22, 0.04, 0.16), Vector3(0.3, 0.47, 0.85), coral)
	_box(root, "BookOcean", Vector3(0.2, 0.04, 0.15), Vector3(0.32, 0.51, 0.87), ocean, Vector3(0, 8, 0))
	_box(root, "Bowl", Vector3(0.2, 0.07, 0.2), Vector3(0.85, 0.49, 1.22), lemon)
	var ph := _box(root, "Phone", Vector3(0.1, 0.016, 0.18), Vector3(0.88, 0.46, 1.08), black)
	ph.rotation_degrees.y = -18
	_box(root, "SideTable", Vector3(0.45, 0.5, 0.45), Vector3(-2.3, 0.25, -1.6), wood)
	_cyl(root, "LampBase", 0.03, 0.45, Vector3(-2.3, 0.73, -1.6), metal)
	_cyl(root, "LampShade", 0.22, 0.26, Vector3(-2.3, 1.02, -1.6), _mat(Color("#c9b08c"), 0.8))
	_omni(root, "LampLight", Vector3(-2.3, 1.0, -1.6), Color("#ffc98f"), 0.62, 3.8, false)

	_box(root, "TvConsole", Vector3(1.85, 0.42, 0.4), Vector3(0.35, 0.21, 2.38), black)
	_box(root, "TvBody", Vector3(1.55, 0.88, 0.07), Vector3(0.35, 1.28, 2.48), black)
	_quad(root, "TvScreen", Vector2(1.4, 0.75), Vector3(0.35, 1.28, 2.44), _emissive(Color("#05070a"), 0.15), Vector3(0, 180, 0))
	_box(root, "Standby", Vector3(0.03, 0.03, 0.01), Vector3(1.05, 0.86, 2.43), _emissive(Color("#d34a3a"), 0.8))
	_box(root, "Soundbar", Vector3(1.25, 0.1, 0.12), Vector3(0.35, 0.49, 2.36), black)
	_box(root, "ArtFrame", Vector3(1.5, 0.9, 0.04), Vector3(-1.5, 1.78, 2.52), trim)
	_box(root, "ArtCanvas", Vector3(1.4, 0.8, 0.02), Vector3(-1.5, 1.78, 2.49), cream)
	_box(root, "ArtRed", Vector3(0.5, 0.38, 0.025), Vector3(-1.78, 1.88, 2.475), coral)
	_box(root, "ArtBlue", Vector3(0.46, 0.5, 0.025), Vector3(-1.28, 1.72, 2.475), ocean)
	_box(root, "ArtYellow", Vector3(0.3, 0.28, 0.025), Vector3(-1.62, 1.55, 2.475), lemon)
	_box(root, "ArtPink", Vector3(0.22, 0.22, 0.025), Vector3(-1.08, 1.98, 2.475), pink)
	_box(root, "MuralFrame", Vector3(1.9, 1.0, 0.04), Vector3(-1.35, 1.75, -2.54), trim)
	_box(root, "MuralCanvas", Vector3(1.8, 0.9, 0.02), Vector3(-1.35, 1.75, -2.515), _mat(Color("#f2e6cc"), 0.8))
	_box(root, "MuralRed", Vector3(0.6, 0.7, 0.025), Vector3(-1.85, 1.75, -2.5), coral)
	_box(root, "MuralBlue", Vector3(0.52, 0.5, 0.025), Vector3(-1.28, 1.82, -2.5), ocean)
	_box(root, "MuralYellow", Vector3(0.45, 0.38, 0.025), Vector3(-0.95, 1.58, -2.5), lemon)
	_box(root, "MuralPink", Vector3(0.26, 0.24, 0.025), Vector3(-1.55, 1.48, -2.5), pink)
	_box(root, "PosterFrame", Vector3(0.52, 0.7, 0.04), Vector3(2.72, 1.72, -2.1), trim)
	_box(root, "Poster", Vector3(0.44, 0.62, 0.02), Vector3(2.7, 1.72, -2.08), ocean)
	_box(root, "PosterSun", Vector3(0.2, 0.2, 0.025), Vector3(2.68, 1.82, -2.07), lemon)
	_box(root, "PosterLine", Vector3(0.3, 0.04, 0.025), Vector3(2.68, 1.56, -2.07), coral)

	_box(root, "DoorFrame", Vector3(1.22, 2.3, 0.08), Vector3(1.1, 1.15, -2.54), trim)
	_box(root, "Door", Vector3(1.05, 2.15, 0.07), Vector3(1.1, 1.075, -2.5), _mat(Color("#2a211b"), 0.7))
	_sphere(root, "Handle", 0.04, Vector3(1.5, 1.02, -2.45), _mat(Color("#b08d52"), 0.3, 0.8))
	_box(root, "Jacket", Vector3(0.38, 0.62, 0.14), Vector3(0.15, 1.55, -2.51), _mat(Color("#1e2224"), 0.92))
	_box(root, "EntryMat", Vector3(1.2, 0.02, 0.7), Vector3(1.1, 0.012, -1.9), _mat(Color("#201b17"), 0.98))

	# Lived-in details
	_cyl(root, "PlantPot", 0.14, 0.24, Vector3(-2.45, 0.37, 1.8), coral)
	_sphere(root, "PlantFoliage", 0.3, Vector3(-2.45, 0.68, 1.8), leaf)
	_sphere(root, "PlantFoliage2", 0.22, Vector3(-2.25, 0.72, 1.65), leaf)
	_cyl(root, "PlantPot2", 0.12, 0.2, Vector3(-2.4, 0.35, -0.9), lemon)
	_sphere(root, "PlantFoliage3", 0.26, Vector3(-2.4, 0.64, -0.9), leaf)
	_cyl(root, "PlantPot3", 0.1, 0.18, Vector3(0.6, 0.34, 2.2), pink)
	_sphere(root, "PlantFoliage4", 0.22, Vector3(0.6, 0.6, 2.2), leaf)
	_box(root, "CoatRack", Vector3(0.6, 0.04, 0.04), Vector3(0.5, 1.6, -2.45), _mat(Color("#1a1612"), 0.9))
	for i in range(9):
		var light_col: Color = [Color("#ffd36a"), Color("#ff7a59"), Color("#5cc8ff"), Color("#ff8fbf")][i % 4]
		_sphere(root, "StringLight", 0.035, Vector3(-2.2 + i * 0.55, 2.55 - sin(i * 0.7) * 0.08, -0.25), _emissive(light_col, 1.4))
	_box(root, "ShoeLeft", Vector3(0.28, 0.1, 0.12), Vector3(1.3, 0.05, -2.0), _mat(Color("#0f0d0b"), 0.95))
	_box(root, "ShoeRight", Vector3(0.28, 0.1, 0.12), Vector3(1.45, 0.05, -2.0), _mat(Color("#0f0d0b"), 0.95))
	_box(root, "WallShelf", Vector3(1.2, 0.06, 0.22), Vector3(-1.0, 1.95, -2.55), _mat(Color("#2a2620"), 0.9))
	for i in range(4):
		var col = [Color("#3a2e24"), Color("#2d3a2d"), Color("#3a2d3a"), Color("#2d2d3a")][i]
		_box(root, "Book", Vector3(0.03, 0.18, 0.15), Vector3(-1.5 + i * 0.3, 2.06, -2.55), _mat(col, 0.9))

	_spot(root, "DawnWindow", Vector3(-2.35, 2.12, 0.2), Vector3(1.4, 0.55, 0.55), Color("#ffd9a8"), 4.6, 9.5, 58.0, true)
	_omni(root, "RoomFill", Vector3(0.0, 2.15, 0.2), Color("#8fc8d8"), 0.5, 6.0, false)
	_omni(root, "WarmCorner", Vector3(-1.8, 1.5, -1.8), Color("#ff8a5c"), 0.55, 3.5, false)
	_omni(root, "CoolCorner", Vector3(1.8, 1.6, 0.9), Color("#5cc8ff"), 0.35, 3.2, false)
	_omni(root, "StringGlow", Vector3(0.0, 2.3, -0.25), Color("#ffc07a"), 0.35, 3.0, false)
	_cyl(root, "PendantCord", 0.012, 0.55, Vector3(-2.0, 2.65, 1.5), trim)
	_cyl(root, "PendantShade", 0.28, 0.18, Vector3(-2.0, 2.38, 1.5), _mat(Color("#2a2724"), 0.8))
	_omni(root, "PendantLight", Vector3(-2.0, 2.32, 1.5), Color("#ffd7ae"), 0.65, 4.5, false)

	_marker(root, "apt_door", Vector3(1.9, 1.52, -2.3), Vector3(-0.2, 1.15, 1.4))
	_marker(root, "apt_window", Vector3(-2.6, 1.5, 0.2), Vector3(0.6, 1.3, 0.4))
	_marker(root, "apt_tv", Vector3(0.35, 1.28, 2.1), Vector3(0.35, 1.1, 0.0))
	_marker(root, "apt_phone", Vector3(0.88, 0.5, 1.08), Vector3(1.2, 0.9, 0.6))
	_marker(root, "apt_low", Vector3(-1.7, 0.8, 2.0), Vector3(1.0, 1.15, -0.8))

	# POV anchors
	_marker(root, "pov_apt_sofa", Vector3(0.2, 1.58, 1.2), Vector3(-2.6, 1.7, 0.2))
	_marker(root, "pov_apt_window", Vector3(-2.6, 1.7, 0.2))
	_marker(root, "pov_apt_door", Vector3(1.1, 1.5, -2.5))
	_marker(root, "pov_apt_door_near", Vector3(0.85, 1.58, -1.35))
	_marker(root, "pov_apt_bed", Vector3(0.2, 1.42, 1.4), Vector3(0.88, 1.02, 1.08))
	_marker(root, "pov_apt_phone", Vector3(0.88, 1.02, 1.08))

	_slot(root, "kexxy", Vector3(-0.2, 0, 0.9))
	_slot(root, "kexxy_start", Vector3(-1.5, 0, 1.9))
	_slot(root, "kexxy_leave", Vector3(0.9, 0, -2.15))
	_save(root, OUT + "/apartment_dawn.tscn")

func _street() -> void:
	_cache.clear()
	var root := _root("StreetBreach")
	var asphalt := _mat(Color("#14181b"), 0.12, 0.55)
	var walk := _mat(Color("#3d3f40"), 0.72)
	var trim := _mat(Color("#1b1d1e"), 0.45, 0.55)
	var line := _mat(Color("#9a9a8e"), 0.6)

	_box(root, "Ground", Vector3(40, 0.2, 60), Vector3(0, -0.2, -3), _mat(Color("#0b0d0f"), 0.95))
	_box(root, "Road", Vector3(10, 0.08, 38), Vector3(0, -0.04, -3), asphalt)
	for x in [-5.9, 5.9]:
		_box(root, "Sidewalk", Vector3(1.8, 0.12, 38), Vector3(x, 0.06, -3), walk)
	for x in [-5.02, 5.02]:
		_box(root, "Curb", Vector3(0.16, 0.16, 38), Vector3(x, 0.08, -3), _mat(Color("#5b5c5a"), 0.7))
	for z in range(-20, 14, 4):
		_box(root, "LaneDash", Vector3(0.12, 0.01, 2.0), Vector3(0, 0.005, float(z)), line)
	for i in range(6):
		_box(root, "CrossStripe", Vector3(0.55, 0.012, 2.6), Vector3(-4.4 + i * 1.75, 0.007, 1.6), _mat(Color("#b3b2a5"), 0.55))
	var puddle := _glass(Color("#101820"), 0.55)
	for i in range(12):
		var x = -3.4 if i % 2 == 0 else 3.1
		var z = -18.0 + i * 2.8
		var p := _plane(root, "Puddle", Vector2(1.6 + (i % 3) * 0.4, 0.9), Vector3(x, 0.008, z), puddle)
		p.rotation_degrees.y = i * 22.0
	_box(root, "Grate", Vector3(0.6, 0.03, 0.9), Vector3(-1.3, 0.01, 3.2), trim)
	_cyl(root, "Manhole", 0.35, 0.02, Vector3(2.0, 0.01, 6.0), trim)

	_building(root, "LeftA", -1, -6.95, -20.0, -10.0, 15.5, Color("#4a4239"), 101)
	_building(root, "LeftB", -1, -7.1, -10.0, 0.0, 11.5, Color("#3f3c37"), 102)
	_building(root, "LeftC", -1, -6.95, 0.0, 14.0, 18.0, Color("#353a3c"), 103)
	_building(root, "RightA", 1, 7.0, -20.0, -8.0, 14.0, Color("#3f3c37"), 201)
	_building(root, "RightB", 1, 7.05, -8.0, 2.0, 11.0, Color("#4a4239"), 202)
	_building(root, "RightC", 1, 6.95, 2.0, 14.0, 17.0, Color("#353a3c"), 203)

	# Facade details: AC units, ledges, drainpipes on both sides
	var facade_trim := _mat(Color("#1b1c1d"), 0.5, 0.5)
	var metal := _mat(Color("#5d6467"), 0.4, 0.6)
	for side in [-1, 1]:
		var wx = side * 6.88
		for z in [-18.0, -14.0, -10.0, -6.0, -2.0, 2.0, 6.0, 10.0]:
			# AC unit
			_box(root, "AC_%s_%s" % [side, z], Vector3(0.45, 0.35, 0.7), Vector3(wx - side * 0.2, 3.3, z), metal)
			# Ledge under windows
			_box(root, "Ledge_%s_%s" % [side, z], Vector3(0.25, 0.06, 1.6), Vector3(wx - side * 0.1, 2.45, z), facade_trim)
			# Drainpipe
			_cyl(root, "Pipe_%s_%s" % [side, z], 0.045, 3.0, Vector3(wx - side * 0.08, 1.5, z + 1.2), metal)

	# Street debris: trash bags, newspapers, cardboard boxes, traffic cones, barricade, suitcase
	var bag_mat := _mat(Color("#0c0d0e"), 0.85)
	var paper_mat := _mat(Color("#e8e4dc"), 0.9)
	var box_mat := _mat(Color("#4a3b2a"), 0.7)
	var cone_mat := _emissive(Color("#ff8800"), 0.8)
	var barricade_mat := _mat(Color("#ffcc00"), 0.6)
	# Trash bags
	for pos in [Vector3(-3.4, 0.15, -16.0), Vector3(3.1, 0.15, -14.5), Vector3(-4.0, 0.15, -8.0), Vector3(4.2, 0.15, -5.0), Vector3(-2.8, 0.15, 2.0), Vector3(3.8, 0.15, 5.0)]:
		_sphere(root, "TrashBag", 0.28, pos, bag_mat)
	# Newspapers (flat quads)
	for pos in [Vector3(-2.5, 0.012, -12.0), Vector3(2.0, 0.012, -9.0), Vector3(-3.0, 0.012, -3.0), Vector3(2.5, 0.012, 1.0)]:
		var p := _plane(root, "Newspaper", Vector2(0.6, 0.8), pos, paper_mat)
		p.rotation_degrees.x = -90
	# Cardboard boxes
	for pos in [Vector3(-4.5, 0.2, -10.0), Vector3(3.4, 0.2, -5.6), Vector3(-1.0, 0.2, 4.0)]:
		_box(root, "CardboardBox", Vector3(0.5, 0.4, 0.5), pos, box_mat)
	# Traffic cones
	for pos in [Vector3(-4.8, 0.25, -14.0), Vector3(4.9, 0.25, -12.0), Vector3(-4.0, 0.25, 0.0), Vector3(4.2, 0.25, 3.0)]:
		_cyl(root, "Cone", 0.12, 0.5, pos, cone_mat)
	# Barricade near intersection (z ~ -7)
	_box(root, "Barricade1", Vector3(2.0, 1.0, 0.1), Vector3(-1.5, 0.5, -7.0), barricade_mat)
	_box(root, "Barricade2", Vector3(2.0, 1.0, 0.1), Vector3(1.5, 0.5, -7.0), barricade_mat)
	# Striped board
	_box(root, "BarricadeBoard", Vector3(3.5, 0.1, 0.05), Vector3(0.0, 1.0, -7.0), _mat(Color("#ffcc00"), 0.8))
	# Suitcase
	_box(root, "Suitcase", Vector3(0.5, 0.3, 0.2), Vector3(-3.0, 0.15, -18.0), _mat(Color("#2a221e"), 0.9))
	_box(root, "SuitcaseHandle", Vector3(0.2, 0.02, 0.04), Vector3(-3.0, 0.3, -17.9), metal)

	_storefront(root, -1, -6.95, 5.4, 3.2, "LAUNDRY", Color("#a9c6d8"), true)
	_storefront(root, -1, -7.1, -4.4, 3.0, "PAWN", Color("#c5a36e"), false)
	_storefront(root, 1, 6.95, 6.4, 2.8, "PHARMACY", Color("#b6e3c2"), true)
	_shutter(root, 1, 6.95, -0.2, 2.6)

	for z in [9.0, -2.0, -13.0]:
		# _lamp(root, "LampL", Vector3(-6.25, 0, z))
		pass
	for z2 in [9.0, -7.5, -13.0]:
		# _lamp(root, "LampR", Vector3(6.25, 0, z2))
		pass
	# _fire_escape(root, Vector3(-6.9, 2.9, -4.6))
	_shelter(root, Vector3(6.18, 0, -1.2))
	_screen(root, Vector3(6.9, 3.2, -4.4))
	_mart_exterior(root)
	_wires(root)
	_distant(root)
	var dawn := DirectionalLight3D.new()
	dawn.name = "DawnFill"
	dawn.rotation_degrees = Vector3(-58.0, -24.0, 0.0)
	dawn.light_color = Color("#8fa9bd")
	dawn.light_energy = 0.32
	dawn.shadow_enabled = false
	root.add_child(dawn)

	_car(root, "CarRight", Vector3(4.15, 0, 6.2), 0.0, Color("#2b3238"), 0.0)
	_car(root, "CarLeft", Vector3(-4.2, 0, 3.0), 180.0, Color("#3b332b"), 0.0)
	_car(root, "CarFar", Vector3(-4.1, 0, -14.0), 180.0, Color("#2a2e31"), 0.0)
	_car(root, "CarCrash", Vector3(1.5, 0, -9.0), 24.0, Color("#3d2825"), 4.0)
	var hazard := _box(root, "Hazard", Vector3(0.18, 0.1, 0.04), Vector3(2.05, 0.58, -7.1), _emissive(Color("#ff9a3c"), 1.4))
	hazard.rotation_degrees.y = 24.0
	_add_state(hazard, "alert")

	# Rain.
	var rain := GPUParticles3D.new()
	rain.name = "Rain"
	rain.amount = 1400
	rain.lifetime = 1.35
	rain.preprocess = 3.0
	rain.position = Vector3(0, 8, -3)
	rain.visibility_aabb = AABB(Vector3(-11, -3, -22), Vector3(22, 14, 44))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(9, 0.5, 18)
	pm.direction = Vector3(0.12, -1.0, 0.02)
	pm.spread = 4.0
	pm.initial_velocity_min = 10.0
	pm.initial_velocity_max = 15.0
	pm.gravity = Vector3(0.3, -2.0, 0.0)
	pm.scale_min = 0.7
	pm.scale_max = 1.2
	pm.color = Color(0.55, 0.68, 0.8, 0.26)
	rain.process_material = pm
	var rq := QuadMesh.new()
	rq.size = Vector2(0.012, 0.48)
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.albedo_color = Color(0.55, 0.68, 0.8, 0.24)
	rm.cull_mode = BaseMaterial3D.CULL_DISABLED
	rm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	rq.material = rm
	rain.draw_pass_1 = rq
	root.add_child(rain)

	_marker(root, "street_walk", Vector3(4.0, 1.55, 1.6), Vector3(5.7, 1.25, 8.0))
	_marker(root, "street_walk_end", Vector3(5.7, 1.2, 2.6), Vector3(5.7, 1.2, -4.0))
	_marker(root, "street_screen", Vector3(3.8, 2.45, 1.0), Vector3(6.88, 3.15, -4.4))
	_marker(root, "screen", Vector3(6.88, 3.15, -4.4), Vector3(3.8, 2.45, 1.0))
	_marker(root, "street_turn", Vector3(4.1, 1.55, 0.6), Vector3(5.3, 1.3, 2.0))
	_marker(root, "street_run", Vector3(2.4, 1.5, -7.2), Vector3(4.0, 1.4, 2.0))
	_marker(root, "street_run_target", Vector3(4.5, 1.4, -13.0), Vector3(4.5, 1.4, -5.0))
	_marker(root, "street_zombie", Vector3(1.6, 1.35, -3.6), Vector3(4.7, 1.2, -8.0))
	_marker(root, "street_mart", Vector3(3.2, 1.55, -1.9), Vector3(6.9, 1.4, -12.0))
	_marker(root, "mart_door", Vector3(6.9, 1.4, -12.0), Vector3(3.2, 1.55, -1.9))
	_marker(root, "phone_bench", Vector3(6.0, 0.6, -1.2), Vector3(3.8, 2.45, 1.0))
	_marker(root, "street_low", Vector3(-3.6, 0.7, 3.0), Vector3(1.0, 1.4, -6.0))
	_marker(root, "street_wide", Vector3(0.0, 2.6, 12.0), Vector3(0.0, 1.4, -8.0))

	# POV anchors
	_marker(root, "pov_street_start", Vector3(5.7, 1.62, 10.0))
	_marker(root, "pov_street_mid", Vector3(5.7, 1.62, 3.0))
	_marker(root, "pov_street_ahead", Vector3(4.9, 1.5, -3.0))
	_marker(root, "pov_screen", Vector3(1.8, 1.62, -3.2))
	_marker(root, "pov_turn", Vector3(3.6, 1.62, -1.5))
	_marker(root, "pov_run_start", Vector3(4.2, 1.58, 2.6))
	_marker(root, "pov_run_end", Vector3(3.7, 1.58, -5.8))
	_marker(root, "pov_run_ahead", Vector3(4.6, 1.35, -10.0))
	_marker(root, "pov_zombie", Vector3(3.0, 1.58, -4.2))
	_marker(root, "pov_hook", Vector3(4.8, 1.5, -4.2), Vector3(4.8, 1.25, -8.0))
	_marker(root, "pov_mart_start", Vector3(3.0, 1.58, -6.6))
	_marker(root, "pov_mart_stop", Vector3(5.35, 1.58, -11.0))
	_marker(root, "pov_mart_approach", Vector3(3.0, 1.58, -6.6), Vector3(6.9, 1.4, -12.0))
	_marker(root, "pov_mart_doorway", Vector3(6.2, 1.58, -11.8), Vector3(4.2, 1.2, -12.0))
	_marker(root, "pov_scream_long", Vector3(6.3, 1.65, -10.9), Vector3(2.0, 1.2, -11.9))
	_marker(root, "pov_scream_target", Vector3(2.0, 1.2, -11.9))
	_marker(root, "pov_girl_outside", Vector3(5.35, 1.55, -11.0), Vector3(3.6, 1.0, -11.9))
	_marker(root, "pov_stand_outside", Vector3(5.05, 1.55, -10.55), Vector3(6.55, 1.18, -10.4))
	_marker(root, "pov_mop", Vector3(4.8, 0.95, -10.45), Vector3(6.55, 0.3, -10.4))
	_mop(root, Vector3(6.55, 0.0, -10.4))
	_marker(root, "mop_stick", Vector3(6.55, 1.18, -10.4))
	_marker(root, "mop_head", Vector3(6.55, 0.3, -10.4))

	_slot(root, "kexxy_walk", Vector3(5.7, 0, 10.0))
	_slot(root, "kexxy_screen", Vector3(5.3, 0, 2.0))
	_slot(root, "kexxy_run", Vector3(4.9, 0, 2.0))
	_slot(root, "kexxy_mart", Vector3(5.7, 0, -12.0))
	_slot(root, "zombie_alley", Vector3(4.9, 0, -8.2))
	_save(root, OUT + "/street_breach.tscn")

func _mart() -> void:
	_cache.clear()
	var root := _root("MartRed")
	var floor_mat := _mat(Color("#1b1d1e"), 0.3)
	var wall := _mat(Color("#35383a"), 0.86)
	var dark := _mat(Color("#121415"), 0.55)
	var metal := _mat(Color("#5d6467"), 0.4, 0.6)
	var tile := _mat(Color("#2a2c2c"), 0.25)

	_box(root, "Floor", Vector3(8.4, 0.12, 10.4), Vector3(0, -0.06, 0), floor_mat)
	_box(root, "Ceiling", Vector3(8.4, 0.1, 10.4), Vector3(0, 3.15, 0), dark)
	_box(root, "WallL", Vector3(0.12, 3.2, 10.4), Vector3(-4.2, 1.6, 0), wall)
	_box(root, "WallR", Vector3(0.12, 3.2, 10.4), Vector3(4.2, 1.6, 0), wall)
	_box(root, "WallBack", Vector3(8.4, 3.2, 0.12), Vector3(0, 1.6, -5.2), wall)
	_box(root, "FrontHeader", Vector3(8.4, 0.7, 0.12), Vector3(0, 2.8, 5.2), dark)
	for x in [-4.15, 4.15]:
		_box(root, "FrontPost", Vector3(0.12, 2.5, 0.12), Vector3(x, 1.25, 5.2), dark)
	_box(root, "Glass", Vector3(8.2, 2.45, 0.04), Vector3(0, 1.22, 5.14), _glass(Color("#8fb8bd"), 0.14))
	_box(root, "DoorFrame", Vector3(1.5, 2.3, 0.1), Vector3(1.2, 1.15, 5.1), dark)
	_box(root, "Door", Vector3(1.25, 2.1, 0.06), Vector3(1.2, 1.05, 5.06), _glass(Color("#6f9aa2"), 0.22))
	_box(root, "EntryMat", Vector3(1.6, 0.02, 0.9), Vector3(1.2, 0.012, 4.4), _mat(Color("#161514"), 0.98))

	for x in [-1.6, 0.4, 2.4]:
		_box(root, "Freezer", Vector3(1.6, 2.3, 0.9), Vector3(x, 1.15, -4.72), _mat(Color("#202628"), 0.5))
		_box(root, "FreezerGlass", Vector3(1.42, 1.8, 0.05), Vector3(x, 1.18, -4.25), _emissive(Color("#8fcab8"), 0.90))
		_box(root, "FreezerRail", Vector3(1.44, 0.06, 0.08), Vector3(x, 0.38, -4.2), metal)
		for y in [0.72, 1.2, 1.68]:
			_box(root, "FreezerShelf", Vector3(1.36, 0.04, 0.5), Vector3(x, y, -4.45), _mat(Color("#8fb6ac"), 0.4))
	_shelf(root, Vector3(-3.55, 0, -1.2), 90.0, 4.2)
	_shelf(root, Vector3(3.55, 0, 1.6), -90.0, 2.8)
	_shelf(root, Vector3(-1.65, 0, -0.9), 90.0, 3.4)
	_shelf(root, Vector3(1.65, 0, -0.9), 90.0, 3.4)
	_shelf(root, Vector3(-3.55, 0, 3.4), 90.0, 2.2)
	_shelf(root, Vector3(3.55, 0, 3.9), 90.0, 1.8)
	_box(root, "Bin", Vector3(1.4, 0.7, 0.6), Vector3(-1.6, 0.35, 2.9), _mat(Color("#3b3a35"), 0.8))
	for i in range(5):
		_box(root, "BinItem", Vector3(0.18, 0.24, 0.18), Vector3(-2.05 + i * 0.22, 0.82, 2.9), _mat([Color("#6f4b34"), Color("#7b2e2b"), Color("#4b5d42"), Color("#8a7444"), Color("#3e4e5c")][i], 0.7))

	_box(root, "Counter", Vector3(1.9, 0.92, 0.8), Vector3(-2.7, 0.46, 3.6), _mat(Color("#33322e"), 0.7))
	_box(root, "CounterTop", Vector3(2.0, 0.06, 0.86), Vector3(-2.7, 0.95, 3.6), _mat(Color("#77746b"), 0.35))
	_box(root, "Register", Vector3(0.42, 0.3, 0.4), Vector3(-2.8, 1.13, 3.6), dark)
	_quad(root, "RegisterGlow", Vector2(0.26, 0.15), Vector3(-2.8, 1.13, 3.39), _emissive(Color("#a9d6c4"), 0.7), Vector3(0, 180, 0))
	_box(root, "Puddle", Vector3(1.4, 0.012, 1.8), Vector3(1.2, 0.008, 0.4), _glass(Color("#bec9bd"), 0.5))
	for i in range(8):
		var c := _cyl(root, "Can", 0.035, 0.12, Vector3(0.6 + float(i % 4) * 0.16, 0.06, -0.4 + float(i / 4) * 0.2), _mat([Color("#8b3a32"), Color("#3f6b5a"), Color("#8a7444")][i % 3], 0.4, 0.4))
		c.rotation_degrees.z = 90.0

	for z in [1.9, -1.0]:
		_box(root, "CeilingTube", Vector3(2.6, 0.05, 0.16), Vector3(0, 3.05, z), _emissive(Color("#cfe4dc"), 1.4))
	_omni(root, "Fluoro", Vector3(0, 2.78, 1.7), Color("#d6e8e0"), 1.05, 8.0, false)
	_omni(root, "FluoroBack", Vector3(0, 2.78, -1.4), Color("#c6ded6"), 0.65, 6.5, false)
	_omni(root, "FreezerLight", Vector3(0.4, 1.8, -3.9), Color("#a6d8c6"), 1.55, 5.5, false)
	# Freezer fog
	var fog := GPUParticles3D.new()
	fog.name = "FreezerFog"
	fog.amount = 80
	fog.lifetime = 4.0
	fog.preprocess = 2.0
	fog.position = Vector3(0.4, 1.0, -3.9)
	fog.visibility_aabb = AABB(Vector3(-2.0, -1.0, -6.0), Vector3(4.0, 3.0, 4.0))
	var fpm := ParticleProcessMaterial.new()
	fpm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	fpm.emission_box_extents = Vector3(1.5, 1.0, 1.5)
	fpm.direction = Vector3(0.0, 0.2, 0.0)
	fpm.spread = 30.0
	fpm.initial_velocity_min = 0.1
	fpm.initial_velocity_max = 0.3
	fpm.gravity = Vector3(0.0, -0.05, 0.0)
	fpm.scale_min = 0.3
	fpm.scale_max = 0.8
	fpm.color = Color(0.6, 0.7, 0.65, 0.12)
	fog.process_material = fpm
	var fq := QuadMesh.new()
	fq.size = Vector2(0.2, 0.2)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.albedo_color = Color(0.6, 0.7, 0.65, 0.12)
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	fq.material = fm
	fog.draw_pass_1 = fq
	root.add_child(fog)

	_omni(root, "FrontFill", Vector3(0.0, 2.25, 3.4), Color("#cfe0da"), 0.55, 7.0, false)
	_omni(root, "AisleFill", Vector3(-2.0, 2.15, -2.0), Color("#aebfb8"), 0.35, 5.0, false)
	_pulse(root, "EmergencyRed", Vector3(0.0, 2.72, -1.4), Color("#ff2a22"), 1.85, 8.5, 1.1, 0.35)
	_cyl(root, "RedBulb", 0.07, 0.12, Vector3(0.0, 2.96, -1.4), _emissive(Color("#ff3a2e"), 2.0))
	_label(root, "BackSign", "OPEN ALL NIGHT", Vector3(0, 2.72, -5.11), 0, 38, Color("#d7f0dc"), 7, 0.004, true, 24)
	_label(root, "AisleSign", "DRINKS", Vector3(0, 2.72, -0.9), 0, 32, Color("#dfe8df"), 5, 0.004, true, 16)
	_label(root, "ExitSign", "EXIT", Vector3(1.2, 2.72, 5.02), 180, 26, Color("#e05b4a"), 5, 0.003, true, 10)

	_marker(root, "mart_entry", Vector3(2.4, 1.55, 4.6), Vector3(0.2, 1.2, -0.8))
	_marker(root, "mart_aisle", Vector3(-0.4, 1.2, -0.8), Vector3(0.2, 1.2, -4.5))
	_marker(root, "mart_girl", Vector3(1.3, 1.15, 0.4), Vector3(2.65, 1.0, -3.9))
	_marker(root, "mart_freeze", Vector3(2.7, 1.0, -4.9), Vector3(0.0, 1.0, -2.0))
	_marker(root, "mart_stand", Vector3(1.05, 1.65, 1.7), Vector3(2.3, 1.1, -2.7))
	_marker(root, "mart_wide", Vector3(0.0, 1.55, 4.8), Vector3(0.0, 1.1, -4.0))

	# POV anchors
	_marker(root, "mart_entry_pov", Vector3(2.2, 1.6, 4.3))
	_marker(root, "mart_aisle_pov", Vector3(0.7, 1.6, 0.0))
	_marker(root, "pov_girl", Vector3(0.8, 1.58, 1.0))
	_marker(root, "pov_stand", Vector3(0.9, 1.6, -0.6))

	# Mop picked up in the aisle
	_mop(root, Vector3(2.9, 0.0, 2.4))
	_marker(root, "mart_mop", Vector3(2.2, 1.15, 2.4), Vector3(2.9, 0.3, 2.4))
	_marker(root, "mop_head", Vector3(2.9, 0.3, 2.4))

	_slot(root, "kexxy", Vector3(-0.4, 0, -0.8))
	_slot(root, "girl", Vector3(2.7, 0, -4.15))
	_slot(root, "zombie", Vector3(2.25, 0, -2.85))
	_save(root, OUT + "/mart_red.tscn")

func _root(n: String) -> Node3D:
	var r := Node3D.new()
	r.name = n
	get_root().add_child(r)
	return r


func _save(root: Node3D, path: String) -> void:
	_own(root, root)
	var ps := PackedScene.new()
	var err := ps.pack(root)
	if err != OK:
		push_error("pack failed: " + path)
		root.free()
		return
	err = ResourceSaver.save(ps, path)
	if err != OK:
		push_error("save failed: " + path)
	else:
		print("saved ", path)
	root.free()


func _own(n: Node, o: Node) -> void:
	for c in n.get_children():
		c.owner = o
		_own(c, o)


func _mat(c: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _emissive(c: Color, e: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c.darkened(0.55)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = e
	m.roughness = 0.45
	return m


func _glass(c: Color, a: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, a)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.08
	m.metallic = 0.35
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _texture_mat(tex: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = tex
	return m


func _box(parent: Node, n: String, size: Vector3, pos: Vector3, mat: Material, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	if mat != null:
		bm.material = mat
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = bm
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


func _plane(parent: Node, n: String, size: Vector2, pos: Vector3, mat: Material) -> MeshInstance3D:
	var pm := PlaneMesh.new()
	pm.size = size
	if mat != null:
		pm.material = mat
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = pm
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _quad(parent: Node, n: String, size: Vector2, pos: Vector3, mat: Material, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var qm := QuadMesh.new()
	qm.size = size
	if mat != null:
		qm.material = mat
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = qm
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


func _cyl(parent: Node, n: String, radius: float, height: float, pos: Vector3, mat: Material, rot_deg := Vector3.ZERO, segs := 12) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = segs
	cm.rings = 1
	if mat != null:
		cm.material = mat
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = cm
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


func _sphere(parent: Node, n: String, radius: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	if mat != null:
		sm.material = mat
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = sm
	mi.position = pos
	parent.add_child(mi)
	return mi

func _label(parent: Node, n: String, text: String, pos: Vector3, rot_y: float, 
font_size: int, c: Color, outline: int, pixel: float, autowrap := true, 
max_width_chars := 32) -> Label3D:
	var l := Label3D.new()
	l.name = n
	l.text = text
	l.position = pos
	l.rotation_degrees.y = rot_y
	l.font_size = font_size
	l.pixel_size = pixel
	l.modulate = c
	l.outline_size = outline
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.shaded = false
	l.double_sided = false
	l.no_depth_test = false
	l.render_priority = 2
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Label3D.width is in text pixels; do not multiply by pixel_size.
	var approx_char_width := font_size * 0.55
	l.width = max_width_chars * approx_char_width
	parent.add_child(l)
	return l


func _marker(parent: Node, n: String, pos: Vector3, look = null) -> Marker3D:
	var m := Marker3D.new()
	m.name = n
	m.position = pos
	parent.add_child(m)
	if look != null:
		var target: Vector3 = look
		var dir := (target - pos).normalized()
		m.basis = Basis.looking_at(dir, Vector3.UP)
	return m


func _slot(parent: Node, n: String, pos: Vector3) -> void:
	_marker(parent, n, pos)


func _add_state(n: Node, state: String) -> Node:
	n.add_to_group("world_state")
	n.set_meta("state", state)
	return n


func _omni(parent: Node, n: String, pos: Vector3, c: Color, e: float, r: float, shadows := false, state := "") -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = n
	l.position = pos
	l.light_color = c
	l.light_energy = e
	l.omni_range = r
	l.omni_attenuation = 1.2
	l.shadow_enabled = shadows
	l.shadow_bias = 0.05
	parent.add_child(l)
	if state != "":
		_add_state(l, state)
	return l


func _pulse(parent: Node, n: String, pos: Vector3, c: Color, e: float, r: float, speed: float, depth: float, state := "alert") -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = n
	l.set_script(PULSE)
	l.position = pos
	l.light_color = c
	l.light_energy = e
	l.omni_range = r
	l.omni_attenuation = 1.2
	l.set("base_energy", e)
	l.set("speed", speed)
	l.set("depth", depth)
	parent.add_child(l)
	_add_state(l, state)
	return l


func _spot(parent: Node, n: String, pos: Vector3, target: Vector3, c: Color, e: float, r: float, angle: float, shadows := false) -> SpotLight3D:
	var s := SpotLight3D.new()
	s.name = n
	s.position = pos
	s.light_color = c
	s.light_energy = e
	s.spot_range = r
	s.spot_angle = angle
	s.spot_angle_attenuation = 0.8
	s.shadow_enabled = shadows
	s.shadow_bias = 0.05
	parent.add_child(s)
	s.basis = Basis.looking_at((target - pos).normalized(), Vector3.UP)
	return s


func _building(parent: Node, n: String, side: int, front: float, z0: float, z1: float, h: float, c: Color, seed: int) -> void:
	var depth := 4.2
	var cx := front + side * depth * 0.5
	var mid := (z0 + z1) * 0.5
	_box(parent, n + "Body", Vector3(depth, h, z1 - z0), Vector3(cx, h * 0.5, mid), _mat(c, 0.9))
	_box(parent, n + "Cornice", Vector3(depth + 0.35, 0.3, z1 - z0 + 0.3), Vector3(cx, h + 0.15, mid), _mat(c.darkened(0.3), 0.9))
	_box(parent, n + "Belt", Vector3(0.18, 0.16, z1 - z0), Vector3(front - side * 0.04, 3.0, mid), _mat(c.darkened(0.4), 0.9))
	_box(parent, n + "ShopBand", Vector3(0.16, 2.9, z1 - z0), Vector3(front - side * 0.07, 1.45, mid), _mat(c.darkened(0.5), 0.9))
	_cyl(parent, n + "Pipe", 0.07, h, Vector3(front - side * 0.12, h * 0.5, z0 + 0.7), _mat(Color("#1f2223"), 0.7, 0.4), Vector3.ZERO, 8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var y := 4.2
	while y + 1.0 < h:
		var z := z0 + 1.3
		while z + 0.9 < z1:
			var skip := side < 0 and z > -6.2 and z < -2.8 and y < 8.0
			if not skip:
				var lit := rng.randf() < 0.16
				var w := _quad(parent, n + "Win", Vector2(1.35, 1.65), Vector3(front - side * 0.035, y, z), _window_mat(lit))
				w.rotation_degrees.y = 90.0 if side < 0 else -90.0
			z += 2.6
		y += 2.5


func _window_mat(lit: bool) -> StandardMaterial3D:
	var key := "win_lit" if lit else "win_dark"
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(64, 96, false, Image.FORMAT_RGBA8)
	img.fill(Color("#0b0e11"))
	var frame := Color("#17191a")
	for x in range(64):
		for y in range(96):
			if x < 4 or x > 59 or y < 4 or y > 91:
				img.set_pixel(x, y, frame)
			elif x in [30, 31, 32, 33] or y in [44, 45, 46]:
				img.set_pixel(x, y, frame)
			else:
				var t := float(y - 6) / 84.0
				var c := Color("#d8a866").lerp(Color("#5a3d27"), t) if lit else Color("#151d24").lerp(Color("#080b0e"), t)
				if (y % 7 == 0) and (x / 8 + y / 9) % 2 == 0:
					c = c.darkened(0.28)
				img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	m.albedo_color = Color(1.5, 1.25, 0.85) if lit else Color(0.8, 0.82, 0.85)
	_cache[key] = m
	return m


func _city_texture() -> ImageTexture:
	if _cache.has("city"):
		return _cache["city"]
	var img := Image.create(512, 256, false, Image.FORMAT_RGBA8)
	for y in range(256):
		var t := float(y) / 256.0
		var sky := Color("#18293a").lerp(Color("#8a7054"), t)
		for x in range(512):
			img.set_pixel(x, y, sky)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var x := 0
	while x < 512:
		var bw := rng.randi_range(18, 58)
		var bh := rng.randi_range(55, 150)
		var base := 256
		for bx in range(x, min(x + bw, 512)):
			for by in range(base - bh, base):
				img.set_pixel(bx, by, Color("#0e151c"))
				if bx % 7 == 0 and by % 11 == 0 and rng.randf() < 0.28:
					img.set_pixel(bx, by, Color("#d4a563"))
		x += bw + rng.randi_range(2, 8)
	var tex := ImageTexture.create_from_image(img)
	_cache["city"] = tex
	return tex


func _storefront(parent: Node, side: int, front: float, z: float, w: float, text: String, c: Color, lit: bool) -> void:
	var x := front - side * 0.18
	_box(parent, "ShopGlass", Vector3(0.06, 1.9, w), Vector3(x, 1.4, z), _glass(Color("#10181c"), 0.55))
	_box(parent, "ShopTop", Vector3(0.16, 0.1, w + 0.2), Vector3(x, 2.4, z), _mat(Color("#202223"), 0.7))
	_box(parent, "ShopBottom", Vector3(0.16, 0.1, w + 0.2), Vector3(x, 0.4, z), _mat(Color("#202223"), 0.7))
	if lit:
		_box(parent, "ShopBack", Vector3(0.03, 1.7, w - 0.2), Vector3(x + side * 0.06, 1.4, z), _emissive(Color("#c89b62"), 0.35))
		_omni(parent, "ShopLight", Vector3(x + side * 0.55, 1.8, z), Color("#ffd2a0"), 0.4, 3.0, false)
	_label(parent, "ShopSign", text, Vector3(x - side * 0.04, 2.62, z), 90 if side < 0 else -90, 40, c, 6, 0.004, true, 20)
	_box(parent, "Awning", Vector3(0.85, 0.08, w + 0.3), Vector3(x - side * 0.5, 2.82, z), _mat(Color("#2a2220"), 0.95))


func _shutter(parent: Node, side: int, front: float, z: float, w: float) -> void:
	var x := front - side * 0.18
	_box(parent, "Shutter", Vector3(0.08, 2.35, w), Vector3(x, 1.4, z), _mat(Color("#2b2d2d"), 0.7, 0.4))
	for i in range(6):
		_box(parent, "Slat", Vector3(0.04, 0.035, w - 0.1), Vector3(x - side * 0.05, 0.45 + i * 0.38, z), _mat(Color("#1b1c1c"), 0.7, 0.5))


func _lamp(parent: Node, n: String, pos: Vector3) -> void:
	var lamp := _instance(parent, "res://open_assets/street_lamp_01/street_lamp_01.gltf", n, pos)
	if lamp == null:
		return
	_sphere(lamp, "Bulb", 0.09, Vector3(0, 3.5, 0), _emissive(Color("#ffd6a0"), 2.4))
	_omni(lamp, "Light", Vector3(0, 3.5, 0), Color("#ffd2a0"), 1.85, 10.0, false)


func _fire_escape(parent: Node, pos: Vector3) -> void:
	_instance(parent, "res://open_assets/modular_fire_escape/modular_fire_escape.gltf", "FireEscape", pos, 0.9, 90.0)


func _shelter(parent: Node, pos: Vector3) -> void:
	var s := Node3D.new()
	s.name = "Shelter"
	s.position = pos
	parent.add_child(s)
	_box(s, "Roof", Vector3(1.5, 0.08, 2.6), Vector3(0, 2.55, 0), _mat(Color("#25292b"), 0.5, 0.5))
	for px in [-0.65, 0.65]:
		for pz in [-1.1, 1.1]:
			_box(s, "Post", Vector3(0.08, 2.55, 0.08), Vector3(px, 1.27, pz), _mat(Color("#25292b"), 0.4, 0.6))
	_box(s, "BackGlass", Vector3(0.04, 2.2, 2.4), Vector3(0.66, 1.35, 0), _glass(Color("#8fb0b8"), 0.18))
	_box(s, "Bench", Vector3(0.55, 0.09, 2.2), Vector3(-0.05, 0.48, 0), _mat(Color("#34302a"), 0.75))
	for bz in [-0.85, 0.85]:
		_box(s, "BenchLeg", Vector3(0.4, 0.45, 0.07), Vector3(-0.05, 0.23, bz), _mat(Color("#1e2021"), 0.5, 0.5))
	var alert := Node3D.new()
	alert.name = "PhoneAlert"
	s.add_child(alert)
	_add_state(alert, "alert")
	for pz in [-1.7, -1.2, -0.7]:
		_box(alert, "Phone", Vector3(0.1, 0.025, 0.18), Vector3(-0.12, 0.55, pz), _mat(Color("#080a0b"), 0.35))
		var q := _quad(alert, "PhoneGlow", Vector2(0.075, 0.14), Vector3(-0.12, 0.568, pz), _emissive(Color("#cfe4ff"), 1.6), Vector3(-90, 0, 0))
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_omni(alert, "PhoneLight", Vector3(-0.12, 0.9, -1.2), Color("#bcd8ff"), 0.7, 2.6, false)
	_label(s, "ShelterAd", "NIGHT\nLINE", Vector3(0.68, 1.5, -0.95), 90, 26, Color("#a8c8d8"), 5, 0.004)


func _screen(parent: Node, pos: Vector3) -> void:
	_box(parent, "ScreenFrame", Vector3(0.18, 3.4, 2.9), pos + Vector3(0.08, 0, 0), _mat(Color("#1a1c1d"), 0.45, 0.5))
	var px := pos.x - 0.055
	var calm := Node3D.new()
	calm.name = "ScreenCalm"
	parent.add_child(calm)
	_add_state(calm, "calm")
	_box(calm, "CalmPanel", Vector3(0.05, 3.0, 2.4), pos + Vector3(-0.02, 0, 0), _emissive(Color("#4f7e95"), 0.8))
	_box(calm, "AdHeader", Vector3(0.012, 0.30, 2.25), Vector3(px, pos.y + 1.32, pos.z), _emissive(Color("#112a3d"), 1.0))
	_label(calm, "AdHeaderText", "CITY 7  LIVE", Vector3(px - 0.012, pos.y + 1.32, pos.z), -90, 24, Color("#e8f4ff"), 5, 0.005, false, 24)
	_box(calm, "AdLiveDot", Vector3(0.02, 0.10, 0.10), Vector3(px - 0.02, pos.y + 1.32, pos.z - 0.92), _emissive(Color("#ff3b30"), 2.0))
	_box(calm, "AdTileLeft", Vector3(0.012, 1.25, 0.98), Vector3(px, pos.y + 0.25, pos.z - 0.62), _emissive(Color("#2f7d78"), 0.9))
	_label(calm, "AdTileLeftText", "MART\nOPEN", Vector3(px - 0.012, pos.y + 0.25, pos.z - 0.62), -90, 34, Color("#ffffff"), 7, 0.006, false, 12)
	_box(calm, "AdTileRight", Vector3(0.012, 1.25, 0.98), Vector3(px, pos.y + 0.25, pos.z + 0.62), _emissive(Color("#b86a2a"), 0.95))
	_label(calm, "AdTileRightText", "14 C\nRAIN", Vector3(px - 0.012, pos.y + 0.25, pos.z + 0.62), -90, 34, Color("#ffffff"), 7, 0.006, false, 12)
	_box(calm, "AdSun", Vector3(0.02, 0.18, 0.18), Vector3(px - 0.018, pos.y + 0.55, pos.z + 0.62), _emissive(Color("#ffd36a"), 2.0))
	_box(calm, "AdCloud", Vector3(0.02, 0.12, 0.30), Vector3(px - 0.018, pos.y + 0.25, pos.z + 0.62), _emissive(Color("#dfe9ef"), 1.2))
	_box(calm, "AdTicker", Vector3(0.012, 0.34, 2.25), Vector3(px, pos.y - 1.18, pos.z), _emissive(Color("#5b1714"), 1.1))
	_label(calm, "AdTickerText", "BREAKING: CITY 7 LOCKDOWN", Vector3(px - 0.012, pos.y - 1.18, pos.z), -90, 17, Color("#ffe4cf"), 4, 0.0045, false, 30)
	_marker(parent, "screen_calm", pos + Vector3(-0.10, 0, 0))
	_omni(calm, "CalmLight", pos + Vector3(-0.55, 0, 0), Color("#8fc4dd"), 0.65, 6.0, false)
	var alert := Node3D.new()
	alert.name = "ScreenAlert"
	parent.add_child(alert)
	_add_state(alert, "alert")
	_box(alert, "AlertPanel", Vector3(0.05, 3.0, 2.4), pos + Vector3(-0.03, 0, 0), _emissive(Color("#b5241e"), 1.3))
	_box(alert, "AlertHeader", Vector3(0.012, 0.34, 2.25), Vector3(px, pos.y + 1.22, pos.z), _emissive(Color("#7a0f0c"), 1.4))
	_label(alert, "AlertHeaderText", "EMERGENCY", Vector3(px - 0.012, pos.y + 1.22, pos.z), -90, 30, Color("#fff0f0"), 7, 0.006, false, 16)
	var alert_text := _label(alert, "AlertText", "EVACUATE\nNOW", Vector3(px - 0.012, pos.y + 0.05, pos.z), -90, 54, Color("#fff0f0"), 11, 0.007, false, 14)
	_box(alert, "AlertTicker", Vector3(0.012, 0.34, 2.25), Vector3(px, pos.y - 1.18, pos.z), _emissive(Color("#450706"), 1.5))
	_label(alert, "AlertTickerText", "SHELTER IN PLACE", Vector3(px - 0.012, pos.y - 1.18, pos.z), -90, 18, Color("#ffd7d0"), 4, 0.0045, false, 24)
	_marker(parent, "screen_alert", pos + Vector3(-0.10, 0, 0))
	alert_text.set_script(PULSE_LABEL)
	alert_text.set("base_color", Color("#fff0f0"))
	alert_text.set("pulse_color", Color("#ff2222"))
	alert_text.set("speed", 5.0)
	_pulse(alert, "AlertLight", pos + Vector3(-0.55, 0, 0), Color("#ff3b30"), 2.5, 10.0, 2.5, 0.5)
	_cyl(alert, "Beacon", 0.12, 0.28, pos + Vector3(-0.02, 1.95, 0), _emissive(Color("#ff2a22"), 2.2))


func _mart_exterior(parent: Node) -> void:
	var trim := _mat(Color("#1b1c1d"), 0.5, 0.5)
	_box(parent, "MartGlass", Vector3(0.06, 2.25, 4.2), Vector3(6.87, 1.32, -12.0), _emissive(Color("#8c6a41"), 0.28))
	for z in [-14.0, -10.0]:
		_box(parent, "MartMullion", Vector3(0.08, 2.35, 0.08), Vector3(6.83, 1.32, z), trim)
	_box(parent, "MartDoorFrame", Vector3(0.09, 2.45, 1.55), Vector3(6.84, 1.22, -12.0), trim)
	_box(parent, "MartDoor", Vector3(0.05, 2.2, 1.3), Vector3(6.80, 1.12, -12.0), _emissive(Color("#d7b578"), 0.55))
	_box(parent, "MartDoorSplit", Vector3(0.07, 2.1, 0.04), Vector3(6.78, 1.12, -12.0), trim)
	_box(parent, "MartCanopy", Vector3(1.0, 0.08, 4.4), Vector3(6.43, 2.62, -12.0), _mat(Color("#262321"), 0.8))
	for z in [-14.0, -10.0]:
		_box(parent, "MartCanopyBrace", Vector3(0.06, 0.06, 0.8), Vector3(6.72, 2.70, z), trim)
	_label(parent, "MartWallSign", "MART", Vector3(6.78, 2.95, -12.0), -90, 50, Color("#ffe1ae"), 8, 0.006, true, 12)
	_box(parent, "MartSignBack", Vector3(1.45, 0.70, 0.08), Vector3(6.18, 3.18, -11.25), _mat(Color("#161514"), 0.6))
	_label(parent, "MartSign", "MART", Vector3(6.18, 3.18, -11.20), 0, 54, Color("#ffe2b0"), 8, 0.007, true, 12)
	_box(parent, "MartSignArm", Vector3(0.30, 0.06, 0.06), Vector3(6.85, 3.18, -11.25), trim)
	_omni(parent, "MartDoorLight", Vector3(6.40, 2.35, -12.0), Color("#ffd3a0"), 1.1, 5.5, false)
	_omni(parent, "MartWindowLight", Vector3(6.40, 1.55, -10.2), Color("#d8b17d"), 0.55, 4.5, false)
	_omni(parent, "ScreamFill", Vector3(0.8, 2.0, -11.4), Color("#8fb4d8"), 0.65, 4.2, false)


func _wires(parent: Node) -> void:
	var m := _mat(Color("#0b0c0d"), 0.8)
	for z in [9.0, 0.0, -9.0]:
		_cyl(parent, "Wire", 0.018, 14.0, Vector3(0, 6.15, z), m, Vector3(0, 0, 90), 5)


func _distant(parent: Node) -> void:
	_box(parent, "DistantBlock", Vector3(24, 16, 4), Vector3(0, 8, -24), _mat(Color("#14191d"), 0.95))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in range(14):
		var w := _quad(parent, "DistantWin", Vector2(1.1, 1.3), Vector3(-9.0 + rng.randf() * 18.0, 4.0 + rng.randf() * 9.0, -21.9), _window_mat(rng.randf() < 0.5))
		w.rotation_degrees.y = 0


func _car(parent: Node, n: String, pos: Vector3, rot_y: float, c: Color, tilt: float) -> void:
	var pivot := Node3D.new()
	pivot.name = n
	pivot.position = pos
	pivot.rotation_degrees = Vector3(0, rot_y, tilt)
	parent.add_child(pivot)
	var body_mat := _mat(c, 0.35, 0.45)
	var glass_mat := _glass(Color("#0e1519"), 0.7)
	var light_mat := _mat(Color("#ffe6b8"), 0.0, 0.0)
	var red_light := _emissive(Color("#c43a2e"), 0.9)
	var amber_light := _emissive(Color("#ffb340"), 0.8)
	var tire_mat := _mat(Color("#0d0e0f"), 0.8)
	var rim_mat := _mat(Color("#3a3d40"), 0.2, 0.9)
	var bumper_mat := _mat(Color("#1a1c1d"), 0.5, 0.3)

	# Main body
	_box(pivot, "BodyLower", Vector3(1.86, 0.42, 4.3), Vector3(0, 0.5, 0), body_mat)
	# Hood
	_box(pivot, "Hood", Vector3(1.78, 0.35, 1.6), Vector3(0, 0.8, 2.0), body_mat)
	# Cabin (greenhouse)
	_box(pivot, "Cabin", Vector3(1.55, 0.65, 2.1), Vector3(0, 1.15, -0.1), glass_mat)
	# Roof
	_box(pivot, "Roof", Vector3(1.6, 0.08, 1.8), Vector3(0, 1.55, -0.15), body_mat)
	# Trunk
	_box(pivot, "Trunk", Vector3(1.78, 0.4, 1.2), Vector3(0, 0.75, -2.4), body_mat)
	# Bumpers
	_box(pivot, "BumperFront", Vector3(1.9, 0.3, 0.15), Vector3(0, 0.55, 2.2), bumper_mat)
	_box(pivot, "BumperRear", Vector3(1.9, 0.3, 0.15), Vector3(0, 0.55, -2.35), bumper_mat)
	# Grille
	_box(pivot, "Grille", Vector3(0.8, 0.25, 0.04), Vector3(0, 0.6, 2.15), _mat(Color("#1a1c1d"), 0.6, 0.5))
	# Headlights
	for sx in [-0.7, 0.7]:
		_box(pivot, "Headlight", Vector3(0.22, 0.1, 0.04), Vector3(sx, 0.62, 2.12), _emissive(Color("#ffe6b8"), 0.9))
		# Turn signal
		_box(pivot, "TurnFront", Vector3(0.12, 0.08, 0.03), Vector3(sx * 1.1, 0.55, 2.0), _emissive(Color("#ffb340"), 0.7))
	# Taillights
	for sx in [-0.65, 0.65]:
		_box(pivot, "Taillight", Vector3(0.2, 0.12, 0.04), Vector3(sx, 0.62, -2.12), red_light)
		_box(pivot, "ReverseLight", Vector3(0.1, 0.08, 0.03), Vector3(sx * 0.5, 0.5, -2.15), _emissive(Color("#ffffff"), 0.6))
	# License plate
	_box(pivot, "Plate", Vector3(0.42, 0.13, 0.02), Vector3(0, 0.46, -2.12), _mat(Color("#c8c6b8"), 0.5))
	# Wheels with rims
	for sx in [-0.84, 0.84]:
		for sz in [-1.35, 1.35]:
			# Tire
			_cyl(pivot, "Tire", 0.33, 0.18, Vector3(sx, 0.33, sz), tire_mat, Vector3(0, 0, 90))
			# Rim
			_cyl(pivot, "Rim", 0.22, 0.06, Vector3(sx, 0.33, sz), rim_mat, Vector3(0, 0, 90))
			# Brake disc
			_cyl(pivot, "BrakeDisc", 0.12, 0.02, Vector3(sx, 0.33, sz), _mat(Color("#2a2a2a"), 0.4), Vector3(0, 0, 90))
	# Side mirrors
	for sx in [-0.95, 0.95]:
		_box(pivot, "Mirror", Vector3(0.04, 0.12, 0.18), Vector3(sx, 1.05, 0.2), _mat(Color("#1a1c1d"), 0.5))
	# Door handles
	for sx in [-0.9, 0.9]:
		_box(pivot, "Handle", Vector3(0.03, 0.06, 0.1), Vector3(sx, 0.9, 0.0), _mat(Color("#3a3d40"), 0.2, 0.8))
	# Exhaust
	_cyl(pivot, "Exhaust", 0.04, 0.4, Vector3(0.7, 0.35, -2.2), _mat(Color("#2a2a2a"), 0.5))
	# Crash car open door (if name contains "Crash")
	if n.find("Crash") != -1:
		# Left front door open 45 deg
		var door = _box(pivot, "DoorOpen", Vector3(0.04, 1.1, 0.9), Vector3(-1.1, 0.9, 0.0), body_mat)
		door.rotation_degrees.y = 45.0


func _mop(parent: Node, pos: Vector3) -> void:
	var m := Node3D.new()
	m.name = "Mop"
	m.position = pos
	m.rotation_degrees = Vector3(0, -18, 8)
	parent.add_child(m)
	var handle_mat := _mat(Color("#8a6a42"), 0.75)
	var head_mat := _mat(Color("#6f746e"), 0.95)
	var fringe_mat := _mat(Color("#d8d4c4"), 1.0)
	_cyl(m, "Handle", 0.025, 1.5, Vector3(0, 0.85, 0), handle_mat)
	_box(m, "MopCrossbar", Vector3(0.46, 0.08, 0.18), Vector3(0, 0.25, 0), head_mat)
	_box(m, "MopBand", Vector3(0.42, 0.07, 0.2), Vector3(0, 0.33, 0), _mat(Color("#c94f3d"), 0.8))
	for i in range(7):
		var fx := -0.18 + i * 0.06
		_box(m, "MopFringe", Vector3(0.05, 0.24, 0.06), Vector3(fx, 0.1, 0), fringe_mat)
	_box(m, "MopHead", Vector3(0.44, 0.08, 0.2), Vector3(0, 0.2, 0), head_mat)


func _shelf(parent: Node, pos: Vector3, rot_y: float, length: float) -> void:
	var s := Node3D.new()
	s.name = "Shelf"
	s.position = pos
	s.rotation_degrees.y = rot_y
	parent.add_child(s)
	var frame := _mat(Color("#4d5456"), 0.45, 0.5)
	_box(s, "Back", Vector3(length, 1.85, 0.06), Vector3(0, 0.95, -0.25), frame)
	for y in [0.45, 0.9, 1.35, 1.8]:
		_box(s, "Deck", Vector3(length, 0.04, 0.5), Vector3(0, y, 0), frame)
	for x in [-length * 0.5, length * 0.5]:
		_box(s, "Side", Vector3(0.05, 1.85, 0.5), Vector3(x, 0.95, 0), frame)
	var cols := [Color("#6f4b34"), Color("#7b2e2b"), Color("#4b5d42"), Color("#8a7444"), Color("#3e4e5c"), Color("#7a6a53")]
	var count := int(length / 0.24)
	for row in [0.45, 0.9, 1.35]:
		for i in range(count):
			var x := -length * 0.5 + 0.16 + i * 0.24
			var c: Color = cols[(i + int(row * 10.0)) % cols.size()]
			_box(s, "Goods", Vector3(0.15, 0.22, 0.26), Vector3(x, row + 0.13, 0.02), _mat(c, 0.7))


func _instance(parent: Node, path: String, n: String, pos: Vector3, scale := 1.0, rot_y := 0.0) -> Node3D:
	var ps: PackedScene = load(path)
	if ps == null:
		push_error("missing asset: " + path)
		return null
	var node := ps.instantiate() as Node3D
	if node == null:
		push_error("not a Node3D: " + path)
		return null
	node.name = n
	node.position = pos
	node.scale = Vector3.ONE * scale
	node.rotation_degrees.y = rot_y
	parent.add_child(node)
	return node



