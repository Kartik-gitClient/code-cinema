extends Node3D

## Code Cinema episode player.
## Reads a resolved screenplay (JSON) + kit manifest, plays the film, and quits.
## Designed for Godot Movie Maker: deterministic, frame-rate independent, silent.
## All audio is assembled later by the Python pipeline from the resolved timeline.

const DEFAULT_LOOK := "night_horror"
const DEFAULT_EPISODE := "res://films/demo/screenplay.json"
const WEAPON_NODES := ["Axe", "Guitar", "Knife", "Pistol", "Rifle", "Shotgun", "SMG", "Spear", "WoodenBat_Barbed", "WoodenBat_Saw"]

const TAU := PI * 2.0

const LOOKS := {
	"night_horror": {
		"bg": "#05080d", "bg_energy": 1.0,
		"ambient": "#1b2635", "ambient_energy": 0.30,
		"fog": "#0a121c", "fog_density": 0.028, "fog_energy": 0.6, "fog_sky": 0.0,
		"glow": 0.7, "glow_bloom": 0.10, "glow_threshold": 0.85,
		"exposure": 1.05, "brightness": 0.98, "contrast": 1.08, "saturation": 0.78,
		"ssao": 0.85, "ssao_radius": 1.2, "tonemap": "filmic"
	},
	"cold_dawn": {
		"bg": "#0d1620", "ambient": "#5a7185", "ambient_energy": 0.55,
		"fog": "#8fa3b3", "fog_density": 0.018, "fog_energy": 0.6,
		"glow": 0.45, "glow_bloom": 0.05, "glow_threshold": 1.0,
		"exposure": 0.95, "brightness": 1.0, "contrast": 1.02, "saturation": 0.72,
		"ssao": 0.5, "ssao_radius": 1.4, "tonemap": "aces"
	},
	"sodium_street": {
		"bg": "#0a0908", "ambient": "#3a2a1c", "ambient_energy": 0.35,
		"fog": "#1c1510", "fog_density": 0.035, "fog_energy": 0.7,
		"glow": 1.0, "glow_bloom": 0.18, "glow_threshold": 0.75,
		"exposure": 1.0, "brightness": 1.0, "contrast": 1.12, "saturation": 0.85,
		"ssao": 0.8, "ssao_radius": 1.0, "tonemap": "filmic"
	},
	"warm_interior": {
		"bg": "#0c0907", "ambient": "#4a3526", "ambient_energy": 0.45,
		"fog": "#1a120c", "fog_density": 0.012, "fog_energy": 0.5,
		"glow": 0.55, "glow_bloom": 0.08, "glow_threshold": 0.95,
		"exposure": 1.1, "brightness": 1.02, "contrast": 1.03, "saturation": 0.95,
		"ssao": 0.6, "ssao_radius": 1.0, "tonemap": "aces"
	},
	"sick_green": {
		"bg": "#050a08", "ambient": "#20352a", "ambient_energy": 0.35,
		"fog": "#0c1a12", "fog_density": 0.04, "fog_energy": 0.8,
		"glow": 0.9, "glow_bloom": 0.12, "glow_threshold": 0.8,
		"exposure": 1.0, "brightness": 0.98, "contrast": 1.1, "saturation": 0.8,
		"ssao": 0.9, "ssao_radius": 1.1, "tonemap": "filmic"
	},
	"bleach": {
		"bg": "#c9c3b4", "ambient": "#d8d2c4", "ambient_energy": 0.8,
		"fog": "#c9c3b4", "fog_density": 0.008, "fog_energy": 0.4,
		"glow": 0.35, "glow_bloom": 0.02, "glow_threshold": 1.1,
		"exposure": 0.9, "brightness": 1.05, "contrast": 1.18, "saturation": 0.25,
		"ssao": 0.4, "ssao_radius": 1.5, "tonemap": "aces"
	}
}

const GRAIN_SHADER := """
shader_type canvas_item;
uniform float grain_amount : hint_range(0.0, 0.35) = 0.055;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.38;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float n = hash(uv * vec2(1920.0, 1080.0) + fract(TIME) * 17.0);
	float d = distance(uv, vec2(0.5));
	float vig = smoothstep(0.32, 0.92, d) * vignette_strength;
	float a = n * grain_amount + vig;
	COLOR = vec4(vec3(0.0), clamp(a, 0.0, 0.82));
}
"""

const GLITCH_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float glitch_amount : hint_range(0.0, 1.0) = 0.0;
uniform float blur_amount : hint_range(0.0, 0.03) = 0.0;
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float band = floor(uv.y * 54.0);
	float tick = floor(TIME * 28.0);
	float n = hash(vec2(band, tick));
	float shift = (n - 0.5) * 0.14 * glitch_amount;
	uv.x += shift;
	float tear = step(0.94, hash(vec2(band, tick + 7.0))) * glitch_amount;
	uv.y += (hash(vec2(band, tick + 3.0)) - 0.5) * 0.045 * tear;
	float chroma = 0.006 * glitch_amount;
	vec3 col;
	col.r = texture(screen_tex, uv + vec2(chroma, 0.0)).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - vec2(chroma, 0.0)).b;
	if (blur_amount > 0.0001) {
		vec2 px = vec2(blur_amount, blur_amount * 0.65);
		vec3 blur = vec3(0.0);
		blur += texture(screen_tex, uv + vec2(px.x, 0.0)).rgb;
		blur += texture(screen_tex, uv - vec2(px.x, 0.0)).rgb;
		blur += texture(screen_tex, uv + vec2(0.0, px.y)).rgb;
		blur += texture(screen_tex, uv - vec2(0.0, px.y)).rgb;
		blur += texture(screen_tex, uv + px).rgb;
		blur += texture(screen_tex, uv - px).rgb;
		col = mix(col, blur / 6.0, 0.85);
	}
	col = mix(col, vec3(1.0), clamp(flash_amount, 0.0, 1.0));
	COLOR = vec4(col, 1.0);
}
"""

var episode: Dictionary = {}
var kit: Dictionary = {}
var style: Dictionary = {}

var camera: Camera3D
var cam_attrs: CameraAttributesPractical
var world_env: WorldEnvironment
var env: Environment
var hud: CanvasLayer
var fp_arms: Node3D
var fp_phone: MeshInstance3D
var fp_arm_left: MeshInstance3D
var fp_arm_right: MeshInstance3D
var fp_coffee: Node3D
var fade_rect: ColorRect
var coffee_sip_at := -1.0
var coffee_duration := 1.0
var coffee_start := -1.0

var title_root: Control
var title_label: Label
var subtitle_label: Label
var caption_label: Label
var card_root: Control
var card_question: Label
var card_options: HBoxContainer
var card_line: Label
var grain: ColorRect
var glitch_overlay: ColorRect
var glitch_mat: ShaderMaterial
var alert_root: Control
var alert_panel: PanelContainer
var alert_title: Label
var alert_body: Label

var opening: Dictionary = {}
var ending: Dictionary = {}
var shots: Array = []
var captions: Array = []
var shot_starts: Array = []

var opening_duration := 0.0
var shots_end := 0.0
var ending_start := -1.0
var ending_duration := 0.0
var total_duration := 0.0

var phase := ""
var active_shot := -1
var shot_start_time := 0.0
var t := 0.0
var finished := false

var location_node: Node3D
var location_name := ""
var actor_nodes: Dictionary = {}
var prop_nodes: Dictionary = {}
var actor_tweens: Dictionary = {}
var anim_change_state: Dictionary = {}
var alert_spec: Dictionary = {}
var alert_start := -1.0
var alert_end := -1.0

var cam_shot: Dictionary = {}
var cam_start_pos := Vector3.ZERO
var cam_end_pos := Vector3.ZERO
var cam_start_basis := Basis.IDENTITY
var cam_end_basis := Basis.IDENTITY
var cam_look_mode := ""
var cam_look_fixed := Vector3.ZERO
var cam_look_actor: Node3D = null
var cam_look_to_mode := ""
var cam_look_to_fixed := Vector3.ZERO
var cam_look_to_actor: Node3D = null
var cam_zoom_from := 60.0
var cam_zoom_to := 60.0
var cam_impact_at := -1.0
var cam_impact_strength := 0.0
var shake_seed := 0.0
var current_look := ""
var ui_scale := 1.0


func _ready() -> void:
	var ep_path := DEFAULT_EPISODE
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--episode="):
			ep_path = arg.substr(10)
		elif arg == "--episode":
			pass
	ep_path = ProjectSettings.globalize_path(ep_path) if ep_path.begins_with("res://") else ep_path

	episode = _load_json(ep_path)
	if episode.is_empty():
		push_error("Code Cinema: could not load episode JSON: " + ep_path)
		get_tree().quit(1)
		return

	kit = _load_json("res://code_cinema/kit.json")
	style = _load_json("res://code_cinema/style.json")
	ui_scale = clampf(minf(get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y) / 1080.0, 0.35, 1.8)

	_build_environment()
	_build_camera()
	_build_ui()
	_build_timeline()
	_layout_ui()
	get_viewport().size_changed.connect(_layout_ui)

	if total_duration <= 0.0:
		push_error("Code Cinema: episode has no duration (no shots).")
		get_tree().quit(1)
		return

	_enter_opening()


func _process(delta: float) -> void:
	if finished:
		return
	t += delta
	_update_phase()
	_update_anim_changes()
	_update_camera(delta)
	_update_glitch()
	_update_captions()
	_update_hud()
	_update_coffee()
	_update_fade()


func _build_environment() -> void:
	world_env = WorldEnvironment.new()
	world_env.name = "FilmEnvironment"
	env = Environment.new()
	world_env.environment = env
	add_child(world_env)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "FilmCamera"
	camera.near = 0.05
	camera.far = 200.0
	camera.fov = 60.0
	cam_attrs = CameraAttributesPractical.new()
	cam_attrs.dof_blur_far_enabled = false
	cam_attrs.dof_blur_near_enabled = false
	camera.attributes = cam_attrs
	add_child(camera)
	camera.current = true

	# First-person arms/hands
	_build_fp_arms()


func _build_fp_arms() -> void:
	fp_arms = Node3D.new()
	fp_arms.name = "FPArms"
	fp_arms.position = Vector3(0.18, -0.35, -0.45)
	camera.add_child(fp_arms)

	# Left arm (holding phone)
	var arm_mat := StandardMaterial3D.new()
	arm_mat.albedo_color = Color("#3a2e2a")
	arm_mat.roughness = 0.8

	# Left forearm
	fp_arm_left = MeshInstance3D.new()
	fp_arm_left.name = "ArmLeft"
	var cyl := CylinderMesh.new()
	cyl.height = 0.35
	cyl.top_radius = 0.045
	cyl.bottom_radius = 0.055
	cyl.radial_segments = 8
	fp_arm_left.mesh = cyl
	fp_arm_left.material_override = arm_mat
	fp_arm_left.rotation_degrees = Vector3(90, 0, -15)
	fp_arm_left.position = Vector3(-0.12, -0.15, -0.1)
	fp_arms.add_child(fp_arm_left)

	# Right forearm
	fp_arm_right = MeshInstance3D.new()
	fp_arm_right.name = "ArmRight"
	var cyl2 := CylinderMesh.new()
	cyl2.height = 0.35
	cyl2.top_radius = 0.045
	cyl2.bottom_radius = 0.055
	cyl2.radial_segments = 8
	fp_arm_right.mesh = cyl2
	fp_arm_right.material_override = arm_mat
	fp_arm_right.rotation_degrees = Vector3(90, 0, 15)
	fp_arm_right.position = Vector3(0.12, -0.15, -0.1)
	fp_arms.add_child(fp_arm_right)

	# Phone in left hand
	fp_phone = MeshInstance3D.new()
	fp_phone.name = "Phone"
	var phone_box := BoxMesh.new()
	phone_box.size = Vector3(0.07, 0.14, 0.01)
	var phone_mat := StandardMaterial3D.new()
	phone_mat.albedo_color = Color("#0a0a0c")
	phone_mat.roughness = 0.3
	phone_mat.metallic = 0.2
	fp_phone.mesh = phone_box
	fp_phone.material_override = phone_mat
	fp_phone.position = Vector3(-0.12, -0.32, -0.18)
	fp_phone.rotation_degrees = Vector3(-10, 0, -10)
	fp_arms.add_child(fp_phone)

	# Phone screen glow
	var screen := MeshInstance3D.new()
	screen.name = "PhoneScreen"
	var screen_quad := QuadMesh.new()
	screen_quad.size = Vector2(0.06, 0.11)
	var screen_mat := StandardMaterial3D.new()
	screen_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	screen_mat.albedo_color = Color("#4a9eff")
	screen_mat.emission_enabled = true
	screen_mat.emission = Color("#4a9eff")
	screen_mat.emission_energy_multiplier = 1.5
	screen_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	screen_mat.albedo_color = Color(0.2, 0.4, 0.8, 0.8)
	screen.mesh = screen_quad
	screen.material_override = screen_mat
	screen.position = Vector3(-0.12, -0.32, -0.17)
	screen.rotation_degrees = Vector3(-10, 0, -10)
	fp_arms.add_child(screen)

	# Coffee mug in right hand
	fp_coffee = Node3D.new()
	fp_coffee.name = "FPCoffee"
	fp_coffee.position = Vector3(0.22, -0.30, -0.55)
	fp_coffee.rotation_degrees = Vector3(-12, 0, -12)
	fp_arms.add_child(fp_coffee)

	var skin_mat := StandardMaterial3D.new()
	skin_mat.albedo_color = Color("#8d5a3b")
	skin_mat.roughness = 0.75

	var hand := MeshInstance3D.new()
	hand.name = "Hand"
	var hand_mesh := CylinderMesh.new()
	hand_mesh.height = 0.18
	hand_mesh.top_radius = 0.05
	hand_mesh.bottom_radius = 0.055
	hand_mesh.radial_segments = 8
	hand.mesh = hand_mesh
	hand.material_override = skin_mat
	hand.rotation_degrees = Vector3(90, 0, -18)
	hand.position = Vector3(0.02, -0.02, 0.12)
	fp_coffee.add_child(hand)

	var mug_mat := StandardMaterial3D.new()
	mug_mat.albedo_color = Color("#e6e1d6")
	mug_mat.roughness = 0.45

	var mug := MeshInstance3D.new()
	mug.name = "Mug"
	var mug_mesh := CylinderMesh.new()
	mug_mesh.height = 0.11
	mug_mesh.top_radius = 0.046
	mug_mesh.bottom_radius = 0.038
	mug_mesh.radial_segments = 12
	mug.mesh = mug_mesh
	mug.material_override = mug_mat
	mug.position = Vector3(0.0, 0.0, 0.0)
	fp_coffee.add_child(mug)

	var coffee_mat := StandardMaterial3D.new()
	coffee_mat.albedo_color = Color("#2a1a12")
	coffee_mat.roughness = 0.25

	var coffee := MeshInstance3D.new()
	coffee.name = "Coffee"
	var coffee_mesh := CylinderMesh.new()
	coffee_mesh.height = 0.012
	coffee_mesh.top_radius = 0.04
	coffee_mesh.bottom_radius = 0.04
	coffee_mesh.radial_segments = 12
	coffee.mesh = coffee_mesh
	coffee.material_override = coffee_mat
	coffee.position = Vector3(0.0, 0.049, 0.0)
	fp_coffee.add_child(coffee)

	fp_arms.visible = false
	fp_coffee.visible = false
	fp_phone.visible = false
	fp_arm_left.visible = false
	fp_arm_right.visible = false

	# Add subtle arm sway script
	var arm_sway_script := GDScript.new()
	arm_sway_script.source_code = '''
extends Node3D
@export var sway_amount := 0.02
@export var sway_speed := 2.0
var _clock := 0.0
func _process(delta: float):
	_clock += delta
	var sway_x := sin(_clock * sway_speed * 2.0) * sway_amount
	var sway_y := sin(_clock * sway_speed * 1.5) * sway_amount * 0.5
	rotation.x = deg_to_rad(sway_y * 5.0)
	rotation.y = deg_to_rad(sway_x * 3.0)
'''
	fp_arms.set_script(arm_sway_script)
	fp_arms.set("sway_amount", 0.015)
	fp_arms.set("sway_speed", 1.8)


func _build_timeline() -> void:
	opening = episode.get("opening", {})
	if typeof(opening) != TYPE_DICTIONARY:
		opening = {}
	shots = episode.get("shots", [])
	if typeof(shots) != TYPE_ARRAY:
		shots = []
	ending = episode.get("ending", {})
	if typeof(ending) != TYPE_DICTIONARY:
		ending = {}

	opening_duration = maxf(0.0, float(opening.get("duration", 0.0)))
	var cursor := opening_duration
	shot_starts.clear()
	for s in shots:
		if typeof(s) != TYPE_DICTIONARY:
			continue
		shot_starts.append(cursor)
		cursor += maxf(0.05, float(s.get("duration", 3.0)))
	shots_end = cursor

	if not ending.is_empty() and (ending.has("question") or ending.has("options")):
		ending_start = cursor
		ending_duration = maxf(0.5, float(ending.get("duration", 5.0)))
		cursor += ending_duration
		total_duration = cursor

	captions = episode.get("captions", [])
	if typeof(captions) != TYPE_ARRAY or captions.is_empty():
		captions = _derive_captions()


func _derive_captions() -> Array:
	var out: Array = []
	for i in range(shots.size()):
		var shot: Dictionary = shots[i]
		var st := float(shot_starts[i])
		for line in shot.get("dialogue", []):
			if typeof(line) != TYPE_DICTIONARY:
				continue
			var text := String(line.get("text", ""))
			if text == "":
				continue
			var start := st + float(line.get("start", 0.0))
			var end := start + float(line.get("duration", 3.0))
			if line.has("end"):
				end = st + float(line["end"])
			out.append({"start": start, "end": end, "text": text})
	return out


func _update_phase() -> void:
	if t < opening_duration:
		if phase != "opening":
			_enter_opening()
		return

	if t < shots_end:
		var idx := _shot_index_at(t)
		if idx >= 0 and idx != active_shot:
			_enter_shot(idx)
		if phase != "shot":
			phase = "shot"
		return

	if ending_start >= 0.0 and t < ending_start + ending_duration:
		if phase != "ending":
			_enter_ending()
		return

	if not finished:
		finished = true
		get_tree().create_timer(0.3).timeout.connect(_finish)


func _finish() -> void:
	get_tree().quit()


func _shot_index_at(time: float) -> int:
	for i in range(shots.size()):
		var start := float(shot_starts[i])
		var dur := float(shots[i].get("duration", 3.0))
		if time >= start and time < start + dur:
			return i
	return -1


func _enter_opening() -> void:
	phase = "opening"
	active_shot = -1
	title_root.visible = true
	card_root.visible = false
	caption_label.visible = false
	alert_root.visible = false
	title_label.text = String(opening.get("title", episode.get("title", ""))).to_upper()
	subtitle_label.text = String(opening.get("subtitle", "")).to_upper()
	title_root.modulate.a = 0.0
	_apply_look(String(opening.get("look", episode.get("style", style.get("look", DEFAULT_LOOK)))))


func _enter_shot(idx: int) -> void:
	active_shot = idx
	phase = "shot"
	shot_start_time = float(shot_starts[idx])
	anim_change_state.clear()
	title_root.visible = false
	card_root.visible = false
	caption_label.visible = true
	caption_label.modulate.a = 0.0

	var shot: Dictionary = shots[idx]
	var loc := String(shot.get("location", episode.get("default_location", "")))
	if loc != location_name:
		_load_location(loc)
	elif location_node == null:
		_load_location(loc)

	_apply_look(String(shot.get("look", episode.get("style", style.get("look", DEFAULT_LOOK)))))
	_apply_world_state(shot)
	_prepare_camera(shot)
	_apply_pov(shot)
	_apply_props(shot)
	_apply_actors(shot)
	_play_location_anim(shot)
	_finish_camera(shot)
	_prepare_alert(shot)
	shake_seed = float(int(abs(hash(String(shot.get("id", "shot")))) % 1000))


func _enter_ending() -> void:
	phase = "ending"
	title_root.visible = false
	caption_label.visible = false
	card_root.visible = true
	alert_root.visible = false
	card_root.modulate.a = 0.0
	card_question.text = String(ending.get("question", "")).to_upper()
	card_line.text = String(ending.get("line", "COMMENT YOUR VOTE")).to_upper()
	for child in card_options.get_children():
		child.queue_free()
	var options: Array = ending.get("options", ["YES", "NO"])
	var palette := [Color("#9fd39a"), Color("#e08374"), Color("#d9c48f"), Color("#9fb7d3")]
	for i in range(options.size()):
		var opt := _make_label(String(options[i]).to_upper(), 62, palette[i % palette.size()], 12)
		opt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_options.add_child(opt)
	_apply_look(String(ending.get("look", current_look)))


func _load_location(name: String) -> void:
	if location_node != null:
		location_node.queue_free()
		location_node = null
	for id in actor_nodes.keys():
		var n = actor_nodes[id]
		if is_instance_valid(n):
			n.queue_free()
		_kill_actor_tween(id)
	actor_nodes.clear()
	for id in prop_nodes.keys():
		var n = prop_nodes[id]
		if is_instance_valid(n):
			n.queue_free()
	prop_nodes.clear()
	location_name = name

	var entry: Dictionary = kit.get("locations", {}).get(name, {})
	if entry.is_empty():
		push_error("Code Cinema: unknown location '" + name + "'")
		return
	var path := String(entry.get("scene", ""))
	var packed: PackedScene = load(path) if path != "" else null
	if packed == null:
		push_error("Code Cinema: cannot load location scene: " + path)
		return
	location_node = packed.instantiate() as Node3D
	if location_node == null:
		push_error("Code Cinema: location root is not Node3D: " + path)
		return
	location_node.name = "Location_" + name
	add_child(location_node)


func _prepare_camera(shot: Dictionary) -> void:
	cam_shot = shot.get("camera", {})
	if typeof(cam_shot) != TYPE_DICTIONARY:
		cam_shot = {}
	var anchor_name := String(cam_shot.get("anchor", ""))
	var pos := Vector3(0.0, 1.6, 3.0)
	var basis := Basis.IDENTITY
	var anchor := _find_anchor(anchor_name)
	if anchor != null:
		pos = anchor.global_position
		basis = anchor.global_transform.basis.orthonormalized()
	elif anchor_name != "":
		push_warning("Code Cinema: camera anchor not found: " + anchor_name)

	camera.global_transform = Transform3D(basis, pos)
	camera.fov = float(cam_shot.get("fov", 60.0))
	camera.near = float(cam_shot.get("near", 0.05))
	camera.far = float(cam_shot.get("far", 200.0))
	camera.current = true

	cam_start_pos = pos
	cam_start_basis = basis
	cam_end_pos = pos
	cam_end_basis = basis
	cam_look_mode = ""
	cam_look_fixed = Vector3.ZERO
	cam_look_actor = null
	cam_look_to_mode = ""
	cam_look_to_fixed = Vector3.ZERO
	cam_look_to_actor = null
	cam_zoom_from = camera.fov
	cam_zoom_to = camera.fov
	cam_impact_at = -1.0
	cam_impact_strength = 0.0


func _finish_camera(shot: Dictionary) -> void:
	cam_impact_at = float(cam_shot.get("impact_at", -1.0))
	cam_impact_strength = float(cam_shot.get("impact", 0.0))
	var look := String(cam_shot.get("look_at", ""))
	if look.begins_with("actor:"):
		var id := look.substr(6)
		if actor_nodes.has(id) and is_instance_valid(actor_nodes[id]):
			cam_look_actor = actor_nodes[id]
			cam_look_mode = "actor"
		else:
			push_warning("Code Cinema: look_at actor not found: " + id)
	elif look.begins_with("anchor:"):
		var node := _find_anchor(look.substr(7))
		if node != null:
			cam_look_fixed = node.global_position
			cam_look_mode = "fixed"
		else:
			push_warning("Code Cinema: look_at anchor not found: " + look.substr(7))

	var look_to := String(cam_shot.get("look_to", ""))
	if look_to.begins_with("actor:"):
		var to_id := look_to.substr(6)
		if actor_nodes.has(to_id) and is_instance_valid(actor_nodes[to_id]):
			cam_look_to_actor = actor_nodes[to_id]
			cam_look_to_mode = "actor"
		else:
			push_warning("Code Cinema: look_to actor not found: " + to_id)
	elif look_to.begins_with("anchor:"):
		var to_node := _find_anchor(look_to.substr(7))
		if to_node != null:
			cam_look_to_fixed = to_node.global_position
			cam_look_to_mode = "fixed"
		else:
			push_warning("Code Cinema: look_to anchor not found: " + look_to.substr(7))

	if cam_look_mode != "":
		var target := _camera_look_target()
		var dir := target - cam_start_pos
		if dir.length() > 0.001:
			cam_start_basis = Basis.looking_at(dir.normalized(), Vector3.UP)
			camera.global_transform = Transform3D(cam_start_basis, cam_start_pos)

	var move := String(cam_shot.get("move", "static"))
	var amount := float(cam_shot.get("amount", 0.5))
	match move:
		"push_in":
			cam_end_pos = cam_start_pos + (-cam_start_basis.z) * amount
		"pull_out":
			cam_end_pos = cam_start_pos + cam_start_basis.z * amount
		"crane_up":
			cam_end_pos = cam_start_pos + Vector3.UP * amount
		"crane_down":
			cam_end_pos = cam_start_pos - Vector3.UP * amount
		"dolly":
			var to_node := _find_anchor(String(cam_shot.get("to", "")))
			if to_node != null:
				cam_end_pos = to_node.global_position
				cam_end_basis = to_node.global_transform.basis.orthonormalized()
			else:
				cam_end_pos = cam_start_pos + (-cam_start_basis.z) * amount
		"pan":
			cam_end_basis = Basis(Vector3.UP, -deg_to_rad(amount)) * cam_start_basis
		"tilt":
			cam_end_basis = Basis(Vector3.RIGHT, deg_to_rad(amount)) * cam_start_basis
		"roll":
			cam_end_basis = cam_start_basis * Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(amount))
		"orbit":
			var center := _camera_look_target()
			if cam_look_mode == "":
				center = cam_start_pos + (-cam_start_basis.z) * 3.0
			var offset := cam_start_pos - center
			cam_end_pos = center + offset.rotated(Vector3.UP, deg_to_rad(amount))
			cam_end_basis = Basis.looking_at((center - cam_end_pos).normalized(), Vector3.UP)
		"zoom":
			cam_zoom_to = camera.fov + amount
		"track":
			pass
		"handheld":
			pass
		_:
			pass

	if cam_look_mode != "" and move != "orbit":
		var end_target := _camera_look_target_to()
		var dir2 := end_target - cam_end_pos
		if dir2.length() > 0.001:
			cam_end_basis = Basis.looking_at(dir2.normalized(), Vector3.UP)

	camera.global_transform = Transform3D(cam_start_basis, cam_start_pos)


func _camera_look_target() -> Vector3:
	if cam_look_mode == "actor" and is_instance_valid(cam_look_actor):
		var h := 1.35
		if cam_look_actor.has_meta("look_height"):
			h = float(cam_look_actor.get_meta("look_height"))
		return cam_look_actor.global_position + Vector3(0.0, h, 0.0)
	if cam_look_mode == "fixed":
		return cam_look_fixed
	return camera.global_position + (-camera.global_transform.basis.z) * 3.0


func _camera_look_target_to() -> Vector3:
	if cam_look_to_mode == "actor" and is_instance_valid(cam_look_to_actor):
		var h := 1.35
		if cam_look_to_actor.has_meta("look_height"):
			h = float(cam_look_to_actor.get_meta("look_height"))
		return cam_look_to_actor.global_position + Vector3(0.0, h, 0.0)
	if cam_look_to_mode == "fixed":
		return cam_look_to_fixed
	return _camera_look_target()


func _update_camera(_delta: float) -> void:
	if active_shot < 0 or active_shot >= shots.size():
		return
	var shot: Dictionary = shots[active_shot]
	var dur := maxf(0.001, float(shot.get("duration", 3.0)))
	var local := clampf(t - shot_start_time, 0.0, dur)
	var u := local / dur
	var e := _ease(u, String(cam_shot.get("ease", "in_out")))
	var move := String(cam_shot.get("move", "static"))


	var pos := cam_start_pos.lerp(cam_end_pos, e)
	var basis := _slerp_basis(cam_start_basis, cam_end_basis, e)

	if move == "track" and cam_look_mode == "actor" and is_instance_valid(cam_look_actor):
		var focus := cam_look_actor.global_position
		pos = focus + Vector3(0.0, 1.7, 2.4)
	elif move == "handheld":
		var amt := float(cam_shot.get("amount", 0.05))
		pos += _handheld_offset(local, amt)

	# Bobbing for first-person walking/running
	var bob_amt := float(cam_shot.get("bob", 0.0))
	var bob_roll := 0.0
	if bob_amt > 0.0:
		var bob_rate := float(cam_shot.get("bob_rate", 1.8))
		var bob_phase := local * TAU * bob_rate
		pos.y += absf(sin(bob_phase)) * bob_amt
		pos.x += sin(bob_phase * 0.5) * bob_amt * 0.35
		bob_roll = sin(bob_phase) * float(cam_shot.get("bob_roll", 0.0))

	# Subtle breathing
	var breath := float(cam_shot.get("breath", 0.0))
	if breath > 0.0:
		pos.y += sin(local * 1.4) * breath

	var shake := float(cam_shot.get("shake", 0.0))
	if shake > 0.0:
		pos += _shake_offset(local, shake)

	var impact_roll := 0.0
	if cam_impact_at >= 0.0 and local >= cam_impact_at:
		var age := local - cam_impact_at
		var decay := exp(-age * 6.5)
		pos += _shake_offset(local * 1.7, cam_impact_strength * decay)
		pos.y -= cam_impact_strength * 0.45 * decay
		impact_roll = sin(age * 47.0) * cam_impact_strength * 18.0 * decay

	camera.global_transform = Transform3D(basis, pos)

	# Look target interpolation (start -> end)
	var target := _camera_look_target()
	if cam_look_to_mode != "":
		var target_to := _camera_look_target_to()
		target = target.lerp(target_to, e)

	if cam_look_mode != "":
		if move == "track" and is_instance_valid(cam_look_actor):
			target = cam_look_actor.global_position + Vector3(0.0, 1.35, 0.0)
		var dir := target - pos
		if dir.length() > 0.001:
			camera.look_at(target, Vector3.UP)

	var roll := float(cam_shot.get("roll", 0.0)) + impact_roll + bob_roll
	if absf(roll) > 0.001:
		camera.rotate_object_local(Vector3(0.0, 0.0, 1.0), deg_to_rad(roll))

	if move == "zoom":
		camera.fov = lerpf(cam_zoom_from, cam_zoom_to, e)

	_update_dof()


func _update_glitch() -> void:
	if glitch_mat == null or glitch_overlay == null:
		return
	var amount := 0.0
	var blur := 0.0
	var flash := 0.0
	if active_shot >= 0 and active_shot < shots.size():
		var shot: Dictionary = shots[active_shot]
		var cam = shot.get("camera", {})
		if typeof(cam) == TYPE_DICTIONARY:
			var at := float(cam.get("glitch_at", -1.0))
			if at >= 0.0:
				var dur := maxf(0.01, float(cam.get("glitch_duration", 0.7)))
				var local := t - shot_start_time
				if local >= at:
					var u := clampf((local - at) / dur, 0.0, 1.0)
					var env := (1.0 - u) * (1.0 - u)
					amount = float(cam.get("glitch_amount", 0.85)) * env
					blur = float(cam.get("blur_amount", 0.014)) * env
					flash = float(cam.get("flash", 0.0)) * maxf(0.0, 1.0 - u * 3.5)
	glitch_mat.set_shader_parameter("glitch_amount", amount)
	glitch_mat.set_shader_parameter("blur_amount", blur)
	glitch_mat.set_shader_parameter("flash_amount", flash)
	glitch_overlay.visible = amount > 0.001 or blur > 0.0001 or flash > 0.001


func _update_dof() -> void:
	var dof: Dictionary = cam_shot.get("dof", {})
	if typeof(dof) != TYPE_DICTIONARY or dof.is_empty():
		cam_attrs.dof_blur_far_enabled = false
		cam_attrs.dof_blur_near_enabled = false
		return
	var focus := 6.0
	var f = dof.get("focus", 6.0)
	if f is String:
		if f.begins_with("actor:"):
			var actor = actor_nodes.get(f.substr(6))
			if actor is Node3D and is_instance_valid(actor):
				focus = camera.global_position.distance_to(actor.global_position + Vector3(0.0, 1.35, 0.0))
		elif f.begins_with("anchor:"):
			var an := _find_anchor(f.substr(7))
			if an != null:
				focus = camera.global_position.distance_to(an.global_position)
	else:
		focus = float(f)
	focus = maxf(0.2, focus)
	cam_attrs.dof_blur_far_enabled = true
	cam_attrs.dof_blur_far_distance = focus + float(dof.get("range", 2.0))
	cam_attrs.dof_blur_far_transition = float(dof.get("transition", 3.0))
	cam_attrs.dof_blur_near_enabled = true
	cam_attrs.dof_blur_near_distance = maxf(0.1, focus - float(dof.get("near", 1.5)))
	cam_attrs.dof_blur_near_transition = float(dof.get("near_transition", 2.0))


func _apply_look(name: String) -> void:
	if name == "":
		name = DEFAULT_LOOK
	if name == current_look:
		return
	current_look = name
	var l := _look(name)
	if bool(l.get("sky", false)):
		var sky := Sky.new()
		var sm := ProceduralSkyMaterial.new()
		sm.sky_top_color = _color(l.get("sky_top", "#6c828f"))
		sm.sky_horizon_color = _color(l.get("sky_horizon", "#cfd2c8"))
		sm.ground_bottom_color = _color(l.get("ground_bottom", "#4d5351"))
		sm.ground_horizon_color = _color(l.get("ground_horizon", "#b9beb6"))
		sm.sun_angle_max = 12.0
		sm.sun_curve = 0.12
		sky.sky_material = sm
		env.sky = sky
		env.background_mode = Environment.BG_SKY
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = _color(l.get("bg", "#05080d"))
		env.background_energy_multiplier = float(l.get("bg_energy", 1.0))
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = _color(l.get("ambient", "#1b2635"))
	env.ambient_light_energy = float(l.get("ambient_energy", 0.3))
	env.tonemap_mode = _tonemap(String(l.get("tonemap", "filmic")))
	env.tonemap_exposure = float(l.get("exposure", 1.0))
	env.glow_enabled = bool(l.get("glow_enabled", true))
	env.glow_intensity = float(l.get("glow", 0.7))
	env.glow_bloom = float(l.get("glow_bloom", 0.1))
	env.glow_hdr_threshold = float(l.get("glow_threshold", 0.85))
	env.fog_enabled = bool(l.get("fog_enabled", true))
	env.fog_light_color = _color(l.get("fog", "#0a121c"))
	env.fog_light_energy = float(l.get("fog_energy", 0.6))
	env.fog_density = float(l.get("fog_density", 0.028))
	env.fog_sky_affect = float(l.get("fog_sky", 0.0))
	env.fog_aerial_perspective = float(l.get("fog_aerial", 0.0))
	env.adjustment_enabled = true
	env.adjustment_brightness = float(l.get("brightness", 1.0))
	env.adjustment_contrast = float(l.get("contrast", 1.06))
	env.adjustment_saturation = float(l.get("saturation", 0.85))
	env.ssao_enabled = bool(l.get("ssao_enabled", true))
	env.ssao_intensity = float(l.get("ssao", 0.8))
	env.ssao_radius = float(l.get("ssao_radius", 1.1))
	if l.has("volumetric"):
		env.volumetric_fog_enabled = bool(l.get("volumetric", false))
		env.volumetric_fog_density = float(l.get("volumetric_density", 0.02))
		env.volumetric_fog_length = float(l.get("volumetric_length", 48.0))
		env.volumetric_fog_emission = _color(l.get("volumetric_emission", "#000000"))


func _look(name: String) -> Dictionary:
	var base: Dictionary = LOOKS.get(name, LOOKS[DEFAULT_LOOK]).duplicate(true)
	var custom: Dictionary = style.get("looks", {})
	if custom.has(name) and typeof(custom[name]) == TYPE_DICTIONARY:
		for k in custom[name].keys():
			base[k] = custom[name][k]
	return base


func _apply_world_state(shot: Dictionary) -> void:
	var state_name := String(shot.get("state", ""))
	if state_name == "":
		return
	var root: Node = location_node if location_node != null else self
	var nodes: Array[Node] = [root]
	nodes.append_array(root.find_children("*", "", true, false))
	for node in nodes:
		if not node.has_meta("state"):
			continue
		var node_state := String(node.get_meta("state", ""))
		var on := node_state == state_name
		if node is Node3D:
			(node as Node3D).visible = on
		elif node is CanvasItem:
			(node as CanvasItem).visible = on


func _apply_actors(shot: Dictionary) -> void:
	if not shot.has("actors"):
		return
	var specs: Array = shot.get("actors", [])
	var keep: Dictionary = {}
	for spec in specs:
		if typeof(spec) != TYPE_DICTIONARY:
			continue
		var id := String(spec.get("id", ""))
		if id == "":
			continue
		keep[id] = true
		var node: Node3D = actor_nodes.get(id)
		if node == null or not is_instance_valid(node):
			node = _spawn_actor(id, spec)
			if node == null:
				continue
			actor_nodes[id] = node
		_place_actor(node, spec)
		_animate_node(node, spec)
		_animate_motion(id, node, spec)
	if bool(shot.get("clear_actors", true)):
		var remove: Array = []
		for id in actor_nodes.keys():
			if not keep.has(id):
				remove.append(id)
		for id in remove:
			var n = actor_nodes[id]
			if is_instance_valid(n):
				n.queue_free()
			_kill_actor_tween(id)
			actor_nodes.erase(id)


func _spawn_actor(id: String, spec: Dictionary) -> Node3D:
	var char_id := String(spec.get("character", ""))
	var entry: Dictionary = kit.get("characters", {}).get(char_id, {})
	if entry.is_empty():
		push_error("Code Cinema: unknown character '" + char_id + "'")
		return null
	var path := String(entry.get("scene", ""))
	var packed: PackedScene = load(path) if path != "" else null
	if packed == null:
		push_error("Code Cinema: cannot load character scene: " + path)
		return null
	var node := packed.instantiate() as Node3D
	if node == null:
		push_error("Code Cinema: character root is not Node3D: " + path)
		return null
	node.name = "Actor_" + id
	var parent: Node = location_node if location_node != null else self
	parent.add_child(node)
	if bool(entry.get("hide_weapons", false)) or bool(spec.get("hide_weapons", false)):
		for mesh in node.find_children("*", "MeshInstance3D", true, false):
			if WEAPON_NODES.has(String(mesh.name)):
				mesh.visible = false
	_attach_extra_anims(node, entry, spec)
	var base_h := float(entry.get("height", 1.8)) * float(spec.get("scale", 1.0))
	var look_h := float(spec.get("look_height", base_h * 0.74))
	node.set_meta("look_height", look_h)
	return node


func _place_actor(node: Node3D, spec: Dictionary) -> void:
	var pos := node.global_position
	if spec.has("position"):
		var p: Array = spec["position"]
		if p.size() >= 3:
			pos = Vector3(float(p[0]), float(p[1]), float(p[2]))
	else:
		var slot := String(spec.get("slot", ""))
		if slot != "":
			var slot_node := _find_slot(slot)
			if slot_node != null:
				pos = slot_node.global_position
			else:
				push_warning("Code Cinema: actor slot not found: " + slot)

	var off: Array = spec.get("offset", [0.0, 0.0, 0.0])
	if off.size() >= 3:
		pos += Vector3(float(off[0]), float(off[1]), float(off[2]))

	var basis := node.global_transform.basis
	var face = spec.get("face", "camera")
	if face is String:
		match String(face):
			"camera":
				var dir := camera.global_position - pos
				dir.y = 0.0
				if dir.length() > 0.01:
					basis = Basis.looking_at(dir.normalized(), Vector3.UP)
			"away":
				var dir2 := pos - camera.global_position
				dir2.y = 0.0
				if dir2.length() > 0.01:
					basis = Basis.looking_at(dir2.normalized(), Vector3.UP)
			_:
				if String(face).begins_with("anchor:"):
					var an := _find_anchor(String(face).substr(7))
					if an != null:
						var dir3 := an.global_position - pos
						dir3.y = 0.0
						if dir3.length() > 0.01:
							basis = Basis.looking_at(dir3.normalized(), Vector3.UP)
				elif String(face).begins_with("actor:"):
					var other := actor_nodes.get(String(face).substr(6)) as Node3D
					if other != null and is_instance_valid(other):
						var dir4: Vector3 = other.global_position - pos
						dir4.y = 0.0
						if dir4.length() > 0.01:
							basis = Basis.looking_at(dir4.normalized(), Vector3.UP)
	elif face is float or face is int:
		basis = Basis(Vector3.UP, deg_to_rad(float(face)))

	node.global_transform = Transform3D(basis, pos)

	var char_id := String(spec.get("character", ""))
	var forward := String(kit.get("characters", {}).get(char_id, {}).get("forward", "-z"))
	match forward:
		"+z":
			node.rotate_y(PI)
		"-x":
			node.rotate_y(-PI * 0.5)
		"+x":
			node.rotate_y(PI * 0.5)

	var s := float(spec.get("scale", 1.0))
	if absf(s - 1.0) > 0.001:
		node.scale = Vector3.ONE * s
	var yaw := float(spec.get("rotation_y", 0.0))
	if absf(yaw) > 0.001:
		node.rotate_y(deg_to_rad(yaw))


func _animate_node(node: Node3D, spec: Dictionary) -> void:
	var anim := String(spec.get("anim", ""))
	if anim == "":
		return
	var ap := _find_anim_player(node)
	if ap == null:
		push_warning("Code Cinema: no AnimationPlayer on " + node.name)
		return
	if anim == "none" or anim == "stop":
		ap.stop()
		return
	if not ap.has_animation(anim):
		push_warning("Code Cinema: missing animation '" + anim + "' on " + node.name)
		return
	var clip := ap.get_animation(anim)
	if bool(spec.get("loop", anim == "walk" or anim == "run")) and clip.loop_mode == Animation.LOOP_NONE:
		clip.loop_mode = Animation.LOOP_LINEAR
	ap.speed_scale = float(spec.get("anim_speed", 1.0))
	ap.play(anim)
	var from := float(spec.get("anim_from", 0.0))
	if bool(spec.get("restart", true)) or from > 0.0:
		ap.seek(from, true)


func _attach_extra_anims(node: Node3D, entry: Dictionary, spec: Dictionary) -> void:
	var extras: Dictionary = {}
	if entry.get("extra_anims") is Dictionary:
		extras.merge(entry["extra_anims"], true)
	if spec.get("extra_anims") is Dictionary:
		extras.merge(spec["extra_anims"], true)
	if extras.is_empty():
		return
	var ap := _find_anim_player(node)
	if ap == null:
		return
	var lib := ap.get_animation_library("")
	if lib == null:
		lib = AnimationLibrary.new()
		ap.add_animation_library("", lib)
	for anim_name in extras.keys():
		var key := String(anim_name)
		if lib.has_animation(key):
			continue
		var res = load(String(extras[anim_name]))
		if res is Animation:
			lib.add_animation(key, res)
		else:
			push_warning("Code Cinema: cannot load extra animation '" + key + "'")


func _update_anim_changes() -> void:
	if phase != "shot" or active_shot < 0 or active_shot >= shots.size():
		return
	var shot: Dictionary = shots[active_shot]
	var local := t - shot_start_time
	for spec in shot.get("actors", []):
		if typeof(spec) != TYPE_DICTIONARY:
			continue
		var changes = spec.get("anim_changes", [])
		if typeof(changes) != TYPE_ARRAY:
			continue
		var id := String(spec.get("id", ""))
		for i in range(changes.size()):
			var change = changes[i]
			if typeof(change) != TYPE_DICTIONARY:
				continue
			if local < float(change.get("at", 0.0)):
				continue
			var key := id + ":" + str(i)
			if anim_change_state.has(key):
				continue
			anim_change_state[key] = true
			var node: Node3D = actor_nodes.get(id)
			if node == null or not is_instance_valid(node):
				continue
			_play_actor_anim(
				node,
				String(change.get("anim", "")),
				float(change.get("from", 0.0)),
				bool(change.get("loop", false)),
				float(change.get("speed", 1.0))
			)


func _play_actor_anim(node: Node3D, anim_name: String, from: float, loop: bool, speed: float) -> void:
	if anim_name == "":
		return
	var ap := _find_anim_player(node)
	if ap == null:
		return
	if not ap.has_animation(anim_name):
		push_warning("Code Cinema: missing animation '" + anim_name + "' on " + node.name)
		return
	var clip := ap.get_animation(anim_name)
	if loop and clip.loop_mode == Animation.LOOP_NONE:
		clip.loop_mode = Animation.LOOP_LINEAR
	ap.speed_scale = speed
	ap.play(anim_name)
	ap.seek(from, true)


func _kill_actor_tween(id: String) -> void:
	if not actor_tweens.has(id):
		return
	var tw = actor_tweens[id]
	if tw is Tween and tw.is_valid():
		tw.kill()
	actor_tweens.erase(id)


func _animate_motion(id: String, node: Node3D, spec: Dictionary) -> void:
	var motion = spec.get("motion", {})
	if typeof(motion) != TYPE_DICTIONARY or motion.is_empty():
		_kill_actor_tween(id)
		return
	_kill_actor_tween(id)
	if motion.has("from"):
		var f: Array = motion["from"]
		if f.size() >= 3:
			node.global_position = Vector3(float(f[0]), float(f[1]), float(f[2]))
	var target := node.global_position
	if motion.has("to"):
		var p: Array = motion["to"]
		if p.size() >= 3:
			target = Vector3(float(p[0]), float(p[1]), float(p[2]))
	elif motion.has("to_slot"):
		var slot_node := _find_slot(String(motion["to_slot"]))
		if slot_node != null:
			target = slot_node.global_position
	else:
		return
	var dur := maxf(0.05, float(motion.get("duration", 2.0)))
	var delay := maxf(0.0, float(motion.get("delay", 0.0)))
	var tw := create_tween()
	match String(motion.get("ease", "out")):
		"linear":
			tw.set_trans(Tween.TRANS_LINEAR)
		"in":
			tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_:
			tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if delay > 0.001:
		tw.tween_interval(delay)
	tw.tween_property(node, "global_position", target, dur)
	actor_tweens[id] = tw


func _apply_props(shot: Dictionary) -> void:
	if not shot.has("props"):
		return
	var specs: Array = shot.get("props", [])
	var keep: Dictionary = {}
	for spec in specs:
		if typeof(spec) != TYPE_DICTIONARY:
			continue
		var id := String(spec.get("id", spec.get("prop", "")))
		if id == "":
			continue
		keep[id] = true
		var node: Node3D = prop_nodes.get(id)
		if node == null or not is_instance_valid(node):
			node = _spawn_prop(id, spec)
			if node == null:
				continue
			prop_nodes[id] = node
		_place_prop(node, spec)
		_animate_node(node, spec)
	if bool(shot.get("clear_props", true)):
		var remove: Array = []
		for id in prop_nodes.keys():
			if not keep.has(id):
				remove.append(id)
		for id in remove:
			var n = prop_nodes[id]
			if is_instance_valid(n):
				n.queue_free()
			prop_nodes.erase(id)


func _apply_pov(shot: Dictionary) -> void:
	var pov = shot.get("pov", {})
	if typeof(pov) != TYPE_DICTIONARY:
		pov = {}
	var mode := String(pov.get("mode", ""))
	if mode == "coffee":
		fp_arms.visible = true
		fp_coffee.visible = true
		fp_phone.visible = false
		fp_arm_left.visible = false
		fp_arm_right.visible = false
		coffee_start = -1.0
	else:
		fp_arms.visible = false
		fp_coffee.visible = false
		coffee_start = -1.0
		coffee_sip_at = -1.0
		if fp_coffee != null:
			fp_coffee.position = Vector3(0.22, -0.30, -0.55)
			fp_coffee.rotation_degrees = Vector3(-12, 0, -12)


func _update_coffee() -> void:
	if fp_coffee == null or not fp_coffee.visible:
		return
	var shot: Dictionary = shots[active_shot] if active_shot >= 0 else {}
	var local := t - shot_start_time
	if coffee_sip_at < 0.0:
		coffee_sip_at = local + 1.1
		coffee_duration = 1.5
	if coffee_start < 0.0 and local >= coffee_sip_at:
		coffee_start = local
	if coffee_start < 0.0:
		return
	var k := clampf((local - coffee_start) / coffee_duration, 0.0, 1.0)
	var s := k
	if k > 0.6:
		s = 1.0 - ((k - 0.6) / 0.4)
	s = clampf(s, 0.0, 1.0)
	s = s * s * (3.0 - 2.0 * s)
	var from := Vector3(0.22, -0.30, -0.55)
	var to := Vector3(0.08, -0.16, -0.42)
	var from_rot := Vector3(-12, 0, -12)
	var to_rot := Vector3(-4, 0, -6)
	fp_coffee.position = from.lerp(to, s)
	fp_coffee.rotation_degrees = from_rot.lerp(to_rot, s)


func _update_fade() -> void:
	if phase != "shot" or fade_rect == null:
		return
	var shot: Dictionary = shots[active_shot]
	var dur := float(shot.get("duration", 0.0))
	var local := t - shot_start_time
	var fin := float(shot.get("fade_in", 0.0))
	var fout := float(shot.get("fade_out", 0.0))
	var a := 0.0
	if fin > 0.0:
		a = maxf(a, 1.0 - clampf(local / fin, 0.0, 1.0))
	if fout > 0.0 and dur > 0.0:
		var rem := dur - local
		a = maxf(a, 1.0 - clampf(rem / fout, 0.0, 1.0))
	fade_rect.color = Color(0.0, 0.0, 0.0, a)
	fade_rect.visible = a > 0.001


func _spawn_prop(id: String, spec: Dictionary) -> Node3D:
	var prop_id := String(spec.get("prop", ""))
	var entry: Dictionary = kit.get("props", {}).get(prop_id, {})
	if entry.is_empty():
		push_error("Code Cinema: unknown prop '" + prop_id + "'")
		return null
	var path := String(entry.get("scene", ""))
	var packed: PackedScene = load(path) if path != "" else null
	if packed == null:
		push_error("Code Cinema: cannot load prop scene: " + path)
		return null
	var node := packed.instantiate() as Node3D
	if node == null:
		return null
	node.name = "Prop_" + id
	var parent: Node = location_node if location_node != null else self
	parent.add_child(node)
	return node


func _place_prop(node: Node3D, spec: Dictionary) -> void:
	var pos := node.global_position
	var anchor := String(spec.get("anchor", ""))
	if anchor != "":
		var an := _find_anchor(anchor)
		if an != null:
			pos = an.global_position
	elif spec.has("position"):
		var p: Array = spec["position"]
		if p.size() >= 3:
			pos = Vector3(float(p[0]), float(p[1]), float(p[2]))
	var off: Array = spec.get("offset", [0.0, 0.0, 0.0])
	if off.size() >= 3:
		pos += Vector3(float(off[0]), float(off[1]), float(off[2]))
	node.global_position = pos
	var yaw := float(spec.get("rotation_y", 0.0))
	if absf(yaw) > 0.001:
		node.rotate_y(deg_to_rad(yaw))
	var s := float(spec.get("scale", 1.0))
	if absf(s - 1.0) > 0.001:
		node.scale = Vector3.ONE * s


func _update_captions() -> void:
	if phase != "shot":
		return
	var active := false
	for c in captions:
		if typeof(c) != TYPE_DICTIONARY:
			continue
		var st := float(c.get("start", 0.0))
		var en := float(c.get("end", st + 2.0))
		if t >= st and t <= en:
			caption_label.text = String(c.get("text", ""))
			var fade := 0.12
			var a := 1.0
			if t < st + fade:
				a = (t - st) / fade
			elif t > en - fade:
				a = maxf(0.0, (en - t) / fade)
			caption_label.modulate.a = clampf(a, 0.0, 1.0)
			active = true
			break
	if not active:
		caption_label.modulate.a = 0.0


func _update_hud() -> void:
	if phase == "opening":
		var local := t
		title_root.modulate.a = _fade_edge(local, opening_duration, 0.45)
		_update_alert(false)
	elif phase == "ending":
		var local := t - ending_start
		card_root.modulate.a = _fade_edge(local, ending_duration, 0.5)
		_update_alert(false)
	else:
		_update_alert(true)


func _prepare_alert(shot: Dictionary) -> void:
	alert_spec = shot.get("alert", {})
	if typeof(alert_spec) != TYPE_DICTIONARY:
		alert_spec = {}
	alert_start = -1.0
	alert_end = -1.0
	if alert_spec.is_empty():
		alert_root.visible = false
		return
	alert_title.text = String(alert_spec.get("title", "EMERGENCY ALERT")).to_upper()
	alert_body.text = String(alert_spec.get("text", "")).to_upper()
	var offset := float(alert_spec.get("start", 0.0))
	var dur := float(alert_spec.get("duration", maxf(0.1, float(shot.get("duration", 3.0)) - offset)))
	alert_start = shot_start_time + offset
	alert_end = alert_start + maxf(0.1, dur)
	alert_root.visible = false


func _update_alert(active_phase: bool) -> void:
	if not active_phase or alert_start < 0.0:
		if alert_root != null:
			alert_root.visible = false
		return
	alert_root.visible = t >= alert_start and t <= alert_end
	if not alert_root.visible:
		return
	var fade := 0.18
	var a := 1.0
	if t < alert_start + fade:
		a = (t - alert_start) / fade
	elif t > alert_end - fade:
		a = maxf(0.0, (alert_end - t) / fade)
	alert_root.modulate.a = clampf(a, 0.0, 1.0)
	alert_panel.modulate.a = 0.9 + sin(t * 8.0) * 0.1


func _fade_edge(local: float, dur: float, fade: float) -> float:
	if dur <= 0.001:
		return 0.0
	var a := clampf(local / fade, 0.0, 1.0)
	a = minf(a, clampf((dur - local) / fade, 0.0, 1.0))
	return a


func _build_ui() -> void:
	hud = CanvasLayer.new()
	hud.name = "HUD"
	hud.layer = 10
	add_child(hud)

	title_root = Control.new()
	title_root.name = "TitleCard"
	_full_rect(title_root)
	title_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_root.visible = false
	hud.add_child(title_root)

	var title_bg := ColorRect.new()
	title_bg.color = Color(0.015, 0.018, 0.024, 1.0)
	_full_rect(title_bg)
	title_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_root.add_child(title_bg)

	var title_margin := MarginContainer.new()
	_full_rect(title_margin)
	title_margin.add_theme_constant_override("margin_left", _ui(72))
	title_margin.add_theme_constant_override("margin_right", _ui(72))
	title_margin.add_theme_constant_override("margin_top", _ui(120))
	title_margin.add_theme_constant_override("margin_bottom", _ui(120))
	title_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_root.add_child(title_margin)

	var title_center := VBoxContainer.new()
	title_center.alignment = BoxContainer.ALIGNMENT_CENTER
	title_center.add_theme_constant_override("separation", _ui(18))
	title_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_margin.add_child(title_center)

	title_label = _make_label("", int(float(style.get("title", {}).get("size", 88.0))), Color("#f4efe6"), 18)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_center.add_child(title_label)

	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(160.0 * ui_scale, maxf(2.0, 3.0 * ui_scale))
	rule.color = Color("#c9a36a")
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_center.add_child(rule)

	subtitle_label = _make_label("", 40, Color("#c9a36a"), 10)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_center.add_child(subtitle_label)

	caption_label = _make_label("", int(float(style.get("caption", {}).get("size", 62.0))), Color("#f4efe6"), int(float(style.get("caption", {}).get("outline", 10.0))))
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption_label.visible = false
	caption_label.modulate.a = 0.0
	hud.add_child(caption_label)

	card_root = Control.new()
	card_root.name = "EndingCard"
	_full_rect(card_root)
	card_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_root.visible = false
	hud.add_child(card_root)

	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.012, 0.016, 0.66)
	_full_rect(dim)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_root.add_child(dim)

	var card_margin := MarginContainer.new()
	_full_rect(card_margin)
	card_margin.add_theme_constant_override("margin_left", _ui(64))
	card_margin.add_theme_constant_override("margin_right", _ui(64))
	card_margin.add_theme_constant_override("margin_top", _ui(140))
	card_margin.add_theme_constant_override("margin_bottom", _ui(140))
	card_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_root.add_child(card_margin)

	var card_center := VBoxContainer.new()
	card_center.alignment = BoxContainer.ALIGNMENT_CENTER
	card_center.add_theme_constant_override("separation", _ui(26))
	card_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_margin.add_child(card_center)

	var kicker := _make_label("YOU DECIDE", 34, Color("#c9a36a"), 8)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_center.add_child(kicker)

	card_question = _make_label("", int(float(style.get("ending", {}).get("size", 54.0))), Color("#f4efe6"), int(float(style.get("ending", {}).get("outline", 10.0))))
	card_question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_center.add_child(card_question)

	card_options = HBoxContainer.new()
	card_options.alignment = BoxContainer.ALIGNMENT_CENTER
	card_options.add_theme_constant_override("separation", _ui(72))
	card_options.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_center.add_child(card_options)

	card_line = _make_label("COMMENT YOUR VOTE", 34, Color("#b9b1a4"), 8)
	card_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_center.add_child(card_line)

	alert_root = Control.new()
	alert_root.name = "EmergencyAlert"
	_full_rect(alert_root)
	alert_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	alert_root.visible = false
	hud.add_child(alert_root)

	alert_panel = PanelContainer.new()
	alert_panel.name = "AlertPanel"
	alert_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var alert_style := StyleBoxFlat.new()
	alert_style.bg_color = Color(0.46, 0.035, 0.025, 0.93)
	alert_style.border_width_left = 8
	alert_style.border_color = Color("#ffd18a")
	alert_style.corner_radius_top_left = 6
	alert_style.corner_radius_top_right = 6
	alert_style.corner_radius_bottom_left = 6
	alert_style.corner_radius_bottom_right = 6
	alert_style.content_margin_left = _ui(26)
	alert_style.content_margin_right = _ui(26)
	alert_style.content_margin_top = _ui(18)
	alert_style.content_margin_bottom = _ui(20)
	alert_panel.add_theme_stylebox_override("panel", alert_style)
	alert_root.add_child(alert_panel)

	var alert_box := VBoxContainer.new()
	alert_box.add_theme_constant_override("separation", 4)
	alert_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	alert_panel.add_child(alert_box)

	var alert_kicker := _make_label("CIVIL DEFENSE  â€¢  LIVE", 22, Color("#ffd18a"), 6)
	alert_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alert_box.add_child(alert_kicker)

	alert_title = _make_label("EMERGENCY ALERT", 42, Color("#fff4e4"), 10)
	alert_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alert_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	alert_box.add_child(alert_title)

	alert_body = _make_label("", 27, Color("#ffe4cf"), 7)
	alert_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alert_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	alert_box.add_child(alert_body)

	grain = ColorRect.new()
	grain.name = "FilmGrain"
	_full_rect(grain)
	grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = GRAIN_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("grain_amount", float(style.get("grain", 0.055)))
	mat.set_shader_parameter("vignette_strength", float(style.get("vignette", 0.38)))
	grain.material = mat
	hud.add_child(grain)

	glitch_overlay = ColorRect.new()
	glitch_overlay.name = "GlitchOverlay"
	_full_rect(glitch_overlay)
	glitch_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glitch_overlay.visible = false
	var glitch_shader := Shader.new()
	glitch_shader.code = GLITCH_SHADER
	glitch_mat = ShaderMaterial.new()
	glitch_mat.shader = glitch_shader
	glitch_overlay.material = glitch_mat
	hud.add_child(glitch_overlay)

	fade_rect = ColorRect.new()
	fade_rect.name = "FadeOverlay"
	_full_rect(fade_rect)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.color = Color(0.0, 0.0, 0.0, 1.0)
	fade_rect.visible = true
	hud.add_child(fade_rect)


func _layout_ui() -> void:
	var win := get_window().size
	var canvas := get_viewport().get_visible_rect().size
	var vertical := win.y >= win.x
	var cap_w := minf(canvas.x * 0.86, canvas.y * 1.0)
	caption_label.anchor_left = 0.5
	caption_label.anchor_right = 0.5
	caption_label.offset_left = -cap_w * 0.5
	caption_label.offset_right = cap_w * 0.5
	if vertical:
		caption_label.anchor_top = 0.68
		caption_label.anchor_bottom = 0.87
	else:
		caption_label.anchor_top = 0.79
		caption_label.anchor_bottom = 0.94
	var alert_w := minf(canvas.x * 0.90, 900.0 * ui_scale)
	alert_panel.anchor_left = 0.5
	alert_panel.anchor_right = 0.5
	alert_panel.anchor_top = 0.0
	alert_panel.anchor_bottom = 0.0
	alert_panel.offset_left = -alert_w * 0.5
	alert_panel.offset_right = alert_w * 0.5
	alert_panel.offset_top = 76.0 * ui_scale
	alert_panel.offset_bottom = 76.0 * ui_scale
	alert_panel.grow_vertical = Control.GROW_DIRECTION_END


func _make_label(text: String, size: int, color: Color, outline: int) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", maxi(1, _ui(size)))
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))
	l.add_theme_constant_override("outline_size", _ui(outline))
	l.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.55))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", maxi(1, _ui(3)))
	return l


func _ui(value: int) -> int:
	return int(round(float(value) * ui_scale))


func _full_rect(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _find_anchor(name: String) -> Node3D:
	if name == "" or location_node == null:
		return null
	var direct := location_node.get_node_or_null("Anchors/" + name)
	if direct is Node3D:
		return direct
	return _find_node_named(location_node, name) as Node3D


func _find_slot(name: String) -> Node3D:
	if name == "" or location_node == null:
		return null
	var direct := location_node.get_node_or_null("Slots/" + name)
	if direct is Node3D:
		return direct
	return _find_node_named(location_node, name) as Node3D


func _find_node_named(root: Node, target: String) -> Node:
	if root.name == target:
		return root
	for child in root.get_children():
		var found := _find_node_named(child, target)
		if found != null:
			return found
	return null


func _play_location_anim(shot: Dictionary) -> void:
	var anim_name := String(shot.get("location_anim", ""))
	if anim_name == "" or location_node == null:
		return
	var from := float(shot.get("location_anim_from", 0.0))
	_play_named_anim(location_node, anim_name, from)


func _play_named_anim(root: Node, anim_name: String, from: float) -> bool:
	if root is AnimationPlayer:
		var ap := root as AnimationPlayer
		if ap.has_animation(anim_name):
			ap.play(anim_name)
			if from > 0.0:
				ap.seek(from, true)
			return true
	for child in root.get_children():
		if _play_named_anim(child, anim_name, from):
			return true
	return false


func _find_anim_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root
	for child in root.get_children():
		var found := _find_anim_player(child)
		if found != null:
			return found
	return null


func _ease(x: float, mode: String) -> float:
	match mode:
		"linear":
			return x
		"in":
			return x * x
		"out":
			return 1.0 - pow(1.0 - x, 2.0)
		_:
			return smoothstep(0.0, 1.0, x)


func _slerp_basis(a: Basis, b: Basis, w: float) -> Basis:
	var qa := a.get_rotation_quaternion()
	var qb := b.get_rotation_quaternion()
	return Basis(qa.slerp(qb, clampf(w, 0.0, 1.0)))


func _shake_offset(time: float, amp: float) -> Vector3:
	var s := shake_seed
	return Vector3(
		sin(time * 37.0 + s) * 0.6 + sin(time * 23.0 + s * 2.0) * 0.4,
		cos(time * 41.0 + s) * 0.5 + sin(time * 19.0 + s * 3.0) * 0.5,
		sin(time * 31.0 + s * 1.7) * 0.4
	) * amp


func _handheld_offset(time: float, amp: float) -> Vector3:
	var drift := Vector3(sin(time * 1.3), sin(time * 1.7) * 0.5, sin(time * 0.9)) * amp
	var jitter := Vector3(sin(time * 13.0), cos(time * 17.0), sin(time * 11.0)) * amp * 0.12
	return drift + jitter


func _color(value, fallback: String = "#ffffff") -> Color:
	if value is Color:
		return value
	if value is String:
		return Color.from_string(value, Color.from_string(fallback, Color.WHITE))
	return Color.from_string(fallback, Color.WHITE)


func _tonemap(name: String) -> int:
	match name:
		"aces":
			return Environment.TONE_MAPPER_ACES
		"agx":
			return Environment.TONE_MAPPER_AGX
		"linear":
			return Environment.TONE_MAPPER_LINEAR
		"reinhardt":
			return Environment.TONE_MAPPER_REINHARDT
		_:
			return Environment.TONE_MAPPER_FILMIC


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Code Cinema: missing JSON file: " + path)
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Code Cinema: invalid JSON object: " + path)
		return {}
	return parsed
