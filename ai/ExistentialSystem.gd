extends Node
class_name ExistentialSystem

@export var base_growth_rate: float = 0.002
@export var decay_rate: float = 0.0005
@export var event_cooldown_days: int = 2
@export var base_threshold: float = 0.65
@export var threshold_variation: float = 0.05

var last_trigger_day: Dictionary = {}


# -------------------------------------------------
# UPDATE PRINCIPAL
# -------------------------------------------------

func update(agent: Agent, current_day: int = 0) -> void:

	if not _is_agent_valid(agent):
		return

	var personality: Dictionary = agent.data.personality

	var introspection: float = clamp(float(personality.get("introspection", 0.5)), 0.0, 1.0)
	var stability: float = clamp(float(personality.get("stability", 0.5)), 0.0, 1.0)

	var loneliness: float = clamp(float(agent.mood.get("loneliness", 0.0)), 0.0, 1.0)
	var stress: float = clamp(float(agent.mood.get("stress", 0.0)), 0.0, 1.0)

	# Presión emocional equilibrada
	var emotional_pressure: float = ((loneliness + stress) * 0.5) * introspection
	var resistance: float = 1.0 - stability
	var growth: float = emotional_pressure * resistance * base_growth_rate

	agent.existential_state += growth

	# Decaimiento natural
	if loneliness < 0.3 and stress < 0.3:
		agent.existential_state -= decay_rate

	agent.existential_state = clamp(agent.existential_state, 0.0, 1.0)

	# Umbral dinámico
	var dynamic_threshold: float = base_threshold + randf_range(-threshold_variation, threshold_variation)
	dynamic_threshold = clamp(dynamic_threshold, 0.4, 0.9)

	if agent.existential_state >= dynamic_threshold:
		_trigger_existential_event(agent, current_day)


# -------------------------------------------------
# EVENTO EXISTENCIAL
# -------------------------------------------------

func _trigger_existential_event(agent: Agent, current_day: int) -> void:

	if not is_instance_valid(agent):
		return

	if agent.awaiting_thought:
		return

	var agent_id: int = agent.get_instance_id()

	if last_trigger_day.has(agent_id):
		var last_day: int = int(last_trigger_day[agent_id])
		if current_day - last_day < event_cooldown_days:
			return

	last_trigger_day[agent_id] = current_day
	agent.awaiting_thought = true

	var ai_manager: AIManager = _get_ai_manager()
	if ai_manager != null:
		ai_manager.request_existential_thought(agent)
	else:
		agent.awaiting_thought = false


# -------------------------------------------------
# AI MANAGER SEGURO
# -------------------------------------------------

func _get_ai_manager() -> AIManager:

	var tree: SceneTree = get_tree()
	if tree == null:
		return null

	var root: Node = tree.get_root()
	if root == null:
		return null

	var node: Node = root.find_child("AIManager", true, false)

	if node is AIManager:
		return node

	return null


# -------------------------------------------------
# VALIDACIÓN CORREGIDA
# -------------------------------------------------

func _is_agent_valid(agent: Agent) -> bool:

	if agent == null:
		return false

	if not is_instance_valid(agent):
		return false

	if agent.data == null:
		return false

	# Aquí está el cambio importante:
	if not agent.data is AgentData:
		return false

	# Verificamos que personality exista y sea Dictionary
	if agent.data.personality == null:
		return false

	if not (agent.data.personality is Dictionary):
		return false

	if agent.mood == null:
		return false

	return true
