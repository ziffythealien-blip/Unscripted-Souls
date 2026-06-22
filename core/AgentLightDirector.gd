extends Node
class_name AgentLightDirector

@export var enabled: bool = true

# Nodo que controla Home Assistant / focos
@export_node_path("Node") var light_controller_path: NodePath

# IDs reales en Home Assistant
@export var light_entity_ids: Array[String] = [
	"light.luz"
]

@export_range(0.0, 1.0, 0.01) var chance_per_time_segment: float = 0.35
@export_range(5.0, 600.0, 1.0) var min_seconds_between_actions: float = 35.0
@export var allow_random_runtime_actions: bool = true
@export_range(5.0, 300.0, 1.0) var runtime_check_interval_sec: float = 20.0
@export_range(0.0, 1.0, 0.01) var runtime_action_chance: float = 0.15

@export var allowed_time_labels: Array[String] = ["Tarde", "Atardecer", "Noche"]

@export var debug_print: bool = true

var _ai_manager: AIManager = null
var _world_clock: Node = null
var _light_controller: Node = null

var _last_action_unix: float = -999999.0
var _runtime_timer: Timer = null

func _ready() -> void:
	randomize()
	call_deferred("_late_setup")

func _late_setup() -> void:
	_ai_manager = _find_ai_manager()
	_world_clock = _find_world_clock()
	_resolve_light_controller()

	if _world_clock != null and _world_clock.has_signal("time_of_day_changed"):
		if not _world_clock.time_of_day_changed.is_connected(_on_time_of_day_changed):
			_world_clock.time_of_day_changed.connect(_on_time_of_day_changed)

	if allow_random_runtime_actions:
		_runtime_timer = Timer.new()
		_runtime_timer.one_shot = false
		_runtime_timer.wait_time = max(1.0, runtime_check_interval_sec)
		_runtime_timer.timeout.connect(_on_runtime_timer_timeout)
		add_child(_runtime_timer)
		_runtime_timer.start()

	if debug_print:
		print("AgentLightDirector listo.")

func _resolve_light_controller() -> void:
	_light_controller = get_node_or_null(light_controller_path)

	if _light_controller == null:
		# fallback automático por nombre
		var root_scene: Node = get_tree().current_scene
		if root_scene == null:
			root_scene = get_tree().get_root()

		var found: Node = root_scene.find_child("LightController", true, false)
		if found == null:
			found = get_tree().get_root().find_child("LightController", true, false)

		if found != null:
			_light_controller = found

	if debug_print:
		if _light_controller == null:
			print("AgentLightDirector: no encontré LightController.")
		else:
			print("AgentLightDirector: controlador encontrado -> ", _light_controller.name, " en ", _light_controller.get_path())
			_print_supported_methods()

func _print_supported_methods() -> void:
	if _light_controller == null:
		return

	var interesting: Array[String] = [
		"turn_on_light",
		"turn_off_light",
		"toggle_light",
		"turn_on",
		"turn_off",
		"toggle",
		"call_service",
		"set_light_state",
		"control_light"
	]

	var found_methods: Array[String] = []
	for m in interesting:
		if _light_controller.has_method(m):
			found_methods.append(m)

	if debug_print:
		print("AgentLightDirector: métodos útiles detectados -> ", found_methods)

func _on_time_of_day_changed(time_label: String, _seg: int = -1) -> void:
	if not enabled:
		return
	if not _is_allowed_time_label(time_label):
		return
	if randf() > chance_per_time_segment:
		return

	_try_random_agent_light_action("segmento " + time_label)

func _on_runtime_timer_timeout() -> void:
	if not enabled:
		return
	if not allow_random_runtime_actions:
		return
	if randf() > runtime_action_chance:
		return

	var current_label: String = _get_current_time_label()
	if not _is_allowed_time_label(current_label):
		return

	_try_random_agent_light_action("evento aleatorio")

func _try_random_agent_light_action(reason: String) -> void:
	if not _can_act_now():
		return

	if _light_controller == null:
		_resolve_light_controller()
		if _light_controller == null:
			_log("⚠ AgentLightDirector no tiene controlador de luces.")
			return

	var agent: Agent = _pick_random_valid_agent()
	if agent == null:
		return

	var entity_id: String = _pick_random_light_id()
	if entity_id == "":
		return

	var action: String = _pick_action_for_time()
	var ok: bool = _execute_light_action(entity_id, action)

	if not ok:
		_log("⚠ No se pudo ejecutar acción de luz para %s" % entity_id)
		return

	_last_action_unix = Time.get_unix_time_from_system()

	var human_action: String = _action_to_spanish(action)
	var msg: String = "%s decidió %s %s" % [
		agent.get_agent_name(),
		human_action,
		entity_id
	]

	if agent.has_method("remember"):
		agent.remember(msg)

	if "current_activity" in agent:
		agent.current_activity = "Controlando luces"

	_log("💡 " + msg + " (" + reason + ")")
	_toast("💡 %s" % msg)

func _execute_light_action(entity_id: String, action: String) -> bool:
	if _light_controller == null:
		return false
	if entity_id.strip_edges() == "":
		return false

	if debug_print:
		print("AgentLightDirector: intentando acción ", action, " sobre ", entity_id)

	match action:
		"turn_on":
			if _light_controller.has_method("turn_on_light"):
				_light_controller.call("turn_on_light", entity_id)
				return true
			if _light_controller.has_method("turn_on"):
				_light_controller.call("turn_on", entity_id)
				return true
			if _light_controller.has_method("set_light_state"):
				_light_controller.call("set_light_state", entity_id, true)
				return true
			if _light_controller.has_method("control_light"):
				_light_controller.call("control_light", entity_id, "turn_on")
				return true

		"turn_off":
			if _light_controller.has_method("turn_off_light"):
				_light_controller.call("turn_off_light", entity_id)
				return true
			if _light_controller.has_method("turn_off"):
				_light_controller.call("turn_off", entity_id)
				return true
			if _light_controller.has_method("set_light_state"):
				_light_controller.call("set_light_state", entity_id, false)
				return true
			if _light_controller.has_method("control_light"):
				_light_controller.call("control_light", entity_id, "turn_off")
				return true

		"toggle":
			if _light_controller.has_method("toggle_light"):
				_light_controller.call("toggle_light", entity_id)
				return true
			if _light_controller.has_method("toggle"):
				_light_controller.call("toggle", entity_id)
				return true
			if _light_controller.has_method("control_light"):
				_light_controller.call("control_light", entity_id, "toggle")
				return true

	if _light_controller.has_method("call_service"):
		var service_name: String = "toggle"
		if action == "turn_on":
			service_name = "turn_on"
		elif action == "turn_off":
			service_name = "turn_off"

		_light_controller.call("call_service", "light", service_name, {"entity_id": entity_id})
		return true

	if debug_print:
		print("AgentLightDirector: ningún método compatible encontrado en ", _light_controller.name)

	return false

func _pick_action_for_time() -> String:
	var time_label: String = _get_current_time_label()

	if time_label == "Noche":
		return "turn_on"
	if time_label == "Atardecer":
		return "toggle"
	if time_label == "Tarde":
		return ["turn_on", "turn_off", "toggle"][randi() % 3]

	return "toggle"

func _pick_random_valid_agent() -> Agent:
	if _ai_manager == null:
		_ai_manager = _find_ai_manager()
	if _ai_manager == null:
		return null

	var valid_agents: Array[Agent] = []
	for a in _ai_manager.agents:
		if a != null and is_instance_valid(a):
			valid_agents.append(a)

	if valid_agents.is_empty():
		return null

	return valid_agents[randi() % valid_agents.size()]

func _pick_random_light_id() -> String:
	var cleaned: Array[String] = []
	for lid in light_entity_ids:
		var s: String = str(lid).strip_edges()
		if s != "":
			cleaned.append(s)

	if cleaned.is_empty():
		return ""

	return cleaned[randi() % cleaned.size()]

func _can_act_now() -> bool:
	var now_unix: float = Time.get_unix_time_from_system()
	return (now_unix - _last_action_unix) >= min_seconds_between_actions

func _is_allowed_time_label(time_label: String) -> bool:
	if allowed_time_labels.is_empty():
		return true
	for t in allowed_time_labels:
		if str(t) == time_label:
			return true
	return false

func _get_current_time_label() -> String:
	if _world_clock == null:
		_world_clock = _find_world_clock()

	if _world_clock != null and _world_clock.has_method("get_time_label"):
		return str(_world_clock.call("get_time_label"))

	return "Mañana"

func _action_to_spanish(action: String) -> String:
	match action:
		"turn_on":
			return "encender"
		"turn_off":
			return "apagar"
		"toggle":
			return "alternar"
		_:
			return "usar"

func _find_ai_manager() -> AIManager:
	var root_scene: Node = get_tree().current_scene
	if root_scene == null:
		root_scene = get_tree().get_root()

	var n: Node = root_scene.find_child("AIManager", true, false)
	if n is AIManager:
		return n as AIManager

	n = get_tree().get_root().find_child("AIManager", true, false)
	if n is AIManager:
		return n as AIManager

	return null

func _find_world_clock() -> Node:
	var root_scene: Node = get_tree().current_scene
	if root_scene == null:
		root_scene = get_tree().get_root()

	var n: Node = root_scene.find_child("WorldClock", true, false)
	if n != null:
		return n

	n = get_tree().get_root().find_child("WorldClock", true, false)
	return n

func _toast(text: String) -> void:
	if Engine.has_singleton("EventBus") and EventBus.has_method("emit_toast"):
		EventBus.emit_toast(text)
	elif debug_print:
		print("[TOAST] ", text)

func _log(text: String) -> void:
	if Engine.has_singleton("EventBus") and EventBus.has_method("emit_log"):
		EventBus.emit_log(text)
	elif debug_print:
		print(text)
