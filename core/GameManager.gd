extends Node
class_name GameManager

var ai_manager: AIManager = null
var world_clock: WorldClock = null
var agents: Array[Agent] = []

@export var initial_agent_count: int = 5
@export var debug_mode: bool = true

var _initialized: bool = false

func _ready() -> void:
	if debug_mode:
		print("GameManager iniciado.")
	call_deferred("_initialize_world_safe")

func _initialize_world_safe() -> void:
	if _initialized:
		return
	_initialized = true

	# UI (seguro)
	SimulationHUD.ensure_exists(get_tree())

	_find_core_systems()

	if world_clock == null:
		push_error("WorldClock no encontrado.")
		return

	if ai_manager == null:
		push_error("AIManager no encontrado.")
		return

	agents = ai_manager.spawn_initial_agents(initial_agent_count)

	if debug_mode:
		print("Agentes activos:", agents.size())

func _find_core_systems() -> void:
	var root_scene: Node = get_tree().current_scene
	if root_scene == null:
		root_scene = get_tree().get_root()

	var ai_node: Node = root_scene.find_child("AIManager", true, false)
	if ai_node is AIManager:
		ai_manager = ai_node as AIManager
	else:
		ai_node = get_tree().get_root().find_child("AIManager", true, false)
		if ai_node is AIManager:
			ai_manager = ai_node as AIManager

	var c_node: Node = root_scene.find_child("WorldClock", true, false)
	if c_node is WorldClock:
		world_clock = c_node as WorldClock
	else:
		c_node = get_tree().get_root().find_child("WorldClock", true, false)
		if c_node is WorldClock:
			world_clock = c_node as WorldClock
