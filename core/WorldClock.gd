extends Node
class_name WorldClock

signal day_started(day_number: int, season: String)
signal time_of_day_changed(time_period: String)
signal year_passed(year_number: int)
signal weather_changed(weather: String)

# Cada "segmento" (Mañana/Tarde/Atardecer/Noche) dura esto:
@export var segment_seconds: float = 60.0

@export var days_per_year: int = 40
@export var time_segments_per_day: int = 4

var current_day: int = 0
var current_year: int = 1
var current_time_segment: int = 0
var current_weather: String = "Despejado"

var timer: Timer
var is_paused: bool = false
var time_scale: float = 1.0

const SEASONS: Array[String] = ["Primavera", "Verano", "Otoño", "Invierno"]
const TIME_LABELS: Array[String] = ["Mañana", "Tarde", "Atardecer", "Noche"]

const WEATHER_OPTIONS: Dictionary = {
	"Primavera": ["Despejado", "Nublado", "Llovizna", "Neblina"],
	"Verano": ["Despejado", "Caluroso", "Tormenta"],
	"Otoño": ["Nublado", "Viento", "Lluvia", "Neblina"],
	"Invierno": ["Frío", "Nublado", "Lluvia", "Neblina"]
}

func _ready() -> void:
	if timer != null:
		return

	_validate_parameters()

	timer = Timer.new()
	timer.one_shot = false
	timer.autostart = true
	timer.timeout.connect(_on_tick)
	add_child(timer)

	_recalculate_timer()

	print("WorldClock iniciado (MASTER). ", get_path())
	_emit_initial_state()

func _on_tick() -> void:
	if is_paused:
		return

	current_time_segment += 1

	if current_time_segment >= time_segments_per_day:
		current_time_segment = 0
		_advance_day()
	else:
		_emit_time_segment()

func _advance_day() -> void:
	current_day += 1

	if current_day > 0 and current_day % days_per_year == 0:
		current_year += 1
		year_passed.emit(current_year)

	var season: String = get_current_season()
	current_weather = _roll_weather(season)

	print("Día", current_day, "| Año", current_year, "| Estación:", season)

	day_started.emit(current_day, season)
	weather_changed.emit(current_weather)

func get_current_season() -> String:
	if days_per_year <= 0:
		return SEASONS[0]

	var season_length: float = float(days_per_year) / float(SEASONS.size())
	if season_length <= 0.0:
		return SEASONS[0]

	var day_in_year: int = current_day % days_per_year
	var idx: int = int(floor(float(day_in_year) / season_length))
	idx = clamp(idx, 0, SEASONS.size() - 1)
	return SEASONS[idx]

func get_time_label() -> String:
	if current_time_segment < 0 or current_time_segment >= TIME_LABELS.size():
		return TIME_LABELS[0]
	return TIME_LABELS[current_time_segment]

func _roll_weather(season: String) -> String:
	var arr: Array = WEATHER_OPTIONS.get(season, ["Despejado"])
	if arr.is_empty():
		return "Despejado"
	return str(arr[randi() % arr.size()])

func _emit_time_segment() -> void:
	time_of_day_changed.emit(get_time_label())

func _emit_initial_state() -> void:
	_emit_time_segment()
	day_started.emit(current_day, get_current_season())
	weather_changed.emit(current_weather)

func _recalculate_timer() -> void:
	if timer == null:
		return
	var seg: float = max(1.0, segment_seconds) / max(0.01, time_scale)
	timer.wait_time = seg

func set_time_scale(scale: float) -> void:
	if scale <= 0:
		return
	time_scale = scale
	_recalculate_timer()

func pause_clock() -> void:
	is_paused = true

func resume_clock() -> void:
	is_paused = false

func _validate_parameters() -> void:
	days_per_year = max(days_per_year, 1)
	time_segments_per_day = max(time_segments_per_day, 1)
	segment_seconds = max(segment_seconds, 1.0)
