extends CanvasLayer
class_name WeatherVFX

static func ensure_exists(tree: SceneTree) -> WeatherVFX:
	if tree == null:
		return null
	var root_scene: Node = tree.current_scene
	if root_scene == null:
		root_scene = tree.get_root()

	var existing: Node = root_scene.find_child("WeatherVFX", true, false)
	if existing is WeatherVFX:
		return existing as WeatherVFX

	var vfx := WeatherVFX.new()
	vfx.name = "WeatherVFX"
	root_scene.add_child.call_deferred(vfx)
	return vfx

@export var fade_time: float = 1.6

var _fog: ColorRect
var _rain: CPUParticles2D
var _leaves: CPUParticles2D

var _season: String = "Primavera"
var _weather: String = "Despejado"

func _ready() -> void:
	layer = 5 # encima del mundo, debajo de UI
	_build()
	_apply()

func bind_clock(clock: WorldClock) -> void:
	if clock == null:
		return
	if not clock.day_started.is_connected(_on_day):
		clock.day_started.connect(_on_day)
	if not clock.weather_changed.is_connected(_on_weather):
		clock.weather_changed.connect(_on_weather)

	_season = clock.get_current_season()
	_weather = clock.current_weather
	_apply()

func _on_day(_d: int, season: String) -> void:
	_season = season
	_apply()

func _on_weather(weather: String) -> void:
	_weather = weather
	_apply()

func _build() -> void:
	var root := Control.new()
	root.name = "VFXRoot"
	root.anchor_left = 0
	root.anchor_top = 0
	root.anchor_right = 1
	root.anchor_bottom = 1
	add_child(root)

	# Fog overlay
	_fog = ColorRect.new()
	_fog.name = "Fog"
	_fog.anchor_left = 0
	_fog.anchor_top = 0
	_fog.anchor_right = 1
	_fog.anchor_bottom = 1
	_fog.color = Color(0.8, 0.85, 0.95, 0.0)
	root.add_child(_fog)

	# Particles parent (in CanvasLayer space)
	var pnode := Node2D.new()
	pnode.name = "Particles"
	add_child(pnode)

	_rain = CPUParticles2D.new()
	_rain.name = "Rain"
	_rain.emitting = false
	_rain.one_shot = false
	_rain.amount = 800
	_rain.lifetime = 1.2
	_rain.speed_scale = 1.0
	_rain.direction = Vector2(0.15, 1.0)
	_rain.gravity = Vector2(0, 1500)
	_rain.spread = 8
	_rain.scale_amount_min = 0.7
	_rain.scale_amount_max = 1.2
	_rain.position = Vector2(640, 20) # se reajusta por rect
	_rain.emission_rect_extents = Vector2(800, 20)
	_rain.texture = _make_dot_texture(Color(0.85, 0.9, 1.0, 0.9))
	pnode.add_child(_rain)

	_leaves = CPUParticles2D.new()
	_leaves.name = "Leaves"
	_leaves.emitting = false
	_leaves.one_shot = false
	_leaves.amount = 120
	_leaves.lifetime = 6.0
	_leaves.direction = Vector2(1.0, 0.2)
	_leaves.gravity = Vector2(0, 260)
	_leaves.spread = 30
	_leaves.scale_amount_min = 0.8
	_leaves.scale_amount_max = 1.6
	_leaves.angular_velocity_min = -3.0
	_leaves.angular_velocity_max = 3.0
	_leaves.position = Vector2(640, 20)
	_leaves.emission_rect_extents = Vector2(800, 40)
	_leaves.texture = _make_dot_texture(Color(0.95, 0.55, 0.15, 0.95))
	pnode.add_child(_leaves)

func _apply() -> void:
	# reset
	var want_rain := false
	var want_fog := false
	var want_leaves := false

	# lluvia
	if _weather in ["Lluvia", "Llovizna", "Tormenta"]:
		want_rain = true

	# neblina
	if _weather == "Neblina":
		want_fog = true

	# hojas otoño
	if _season == "Otoño":
		want_leaves = true

	_set_particles(_rain, want_rain)
	_set_particles(_leaves, want_leaves)

	# fog intensity (suave)
	var target_a: float = 0.0
	if want_fog:
		target_a = 0.20
	elif _weather == "Nublado":
		target_a = 0.08
	elif _weather == "Frío":
		target_a = 0.10

	_fade_fog(target_a)

func _set_particles(p: CPUParticles2D, on: bool) -> void:
	if p == null:
		return
	p.emitting = on

func _fade_fog(alpha: float) -> void:
	if _fog == null:
		return
	var tw := create_tween()
	tw.tween_property(_fog, "color:a", clamp(alpha, 0.0, 0.35), max(0.1, fade_time))

func _make_dot_texture(c: Color) -> Texture2D:
	var img := Image.create(3, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(6):
		for x in range(3):
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)
