extends Node
class_name Planner

@export var rumor_chance: float = 0.2

# Simula “hora” para el plan (simple): 4 segmentos
const TIME_LABELS: Array[String] = ["Mañana", "Tarde", "Atardecer", "Noche"]

func generate_schedule(agent: Agent, all_agents: Array[Agent]) -> void:
	if agent == null or not is_instance_valid(agent):
		return

	_ensure_needs(agent)
	_update_needs(agent)

	# Si el agent no tiene plan para el día, armamos uno “ligero”
	_build_today_plan_if_needed(agent)

	var social_need: float = float(agent.needs.get("social", 0.0))
	var curiosity: float = float(agent.needs.get("curiosity", 0.0))

	# PRIORIDAD 1: SOCIAL
	if social_need > 0.6:
		var target: Agent = _find_affinity_target(agent, all_agents)
		if target != null and is_instance_valid(target):
			agent.add_plan_item("🤝 (" + _pick_time_label() + ") Visitar a " + target.get_agent_name())
			agent.set_social_target(target)
			return

	# PRIORIDAD 2: RUMOR
	if curiosity > 0.65 and randf() < rumor_chance:
		var rumor_target: Agent = _random_agent(agent, all_agents)
		if rumor_target != null and is_instance_valid(rumor_target):
			agent.add_plan_item("🗣️ (" + _pick_time_label() + ") Escuchar rumor sobre " + rumor_target.get_agent_name())
			agent.remember("Escuchó un rumor sobre " + rumor_target.get_agent_name())
			return

	# PRIORIDAD 3: VAGAR
	agent.add_plan_item("🚶 (" + _pick_time_label() + ") Explorar el pueblo")
	agent.start_wandering()

func _build_today_plan_if_needed(agent: Agent) -> void:
	# Si no existe, no hacemos nada
	if not ("today_plan" in agent):
		return

	# Si ya tiene items, lo dejamos
	if agent.today_plan != null and agent.today_plan.size() > 0:
		return

	# Plan base mínimo
	agent.add_plan_item("☀️ (Mañana) Dar una vuelta")
	agent.add_plan_item("🍵 (Tarde) Descansar / charlar")
	agent.add_plan_item("🌆 (Atardecer) Curiosear")
	agent.add_plan_item("🌙 (Noche) Reflexionar")

func _pick_time_label() -> String:
	return TIME_LABELS[randi() % TIME_LABELS.size()]

# =====================================================
# NEEDS
# =====================================================

func _ensure_needs(agent: Agent) -> void:
	if agent.needs == null:
		agent.needs = {}
	if not agent.needs.has("social"):
		agent.needs["social"] = 0.5
	if not agent.needs.has("curiosity"):
		agent.needs["curiosity"] = 0.5

func _update_needs(agent: Agent) -> void:
	var social: float = float(agent.needs.get("social", 0.5))
	var curiosity: float = float(agent.needs.get("curiosity", 0.5))

	social = clampf(social + randf_range(-0.1, 0.2), 0.0, 1.0)
	curiosity = clampf(curiosity + randf_range(-0.05, 0.15), 0.0, 1.0)

	agent.needs["social"] = social
	agent.needs["curiosity"] = curiosity

# =====================================================
# SELECCIÓN POR AFINIDAD
# =====================================================

func _find_affinity_target(agent: Agent, all_agents: Array[Agent]) -> Agent:
	var best_target: Agent = null
	var highest_affinity: float = -9999.0

	for other in all_agents:
		if other == null or not is_instance_valid(other):
			continue
		if other == agent:
			continue

		var affinity: float = _safe_affinity(agent, other)
		if affinity > highest_affinity:
			highest_affinity = affinity
			best_target = other

	return best_target

func _safe_affinity(agent: Agent, other: Agent) -> float:
	if agent == null or other == null:
		return -9999.0

	if agent.has_method("get_affinity_with"):
		return float(agent.get_affinity_with(other))

	if other.data != null:
		var oid: String = str(other.data.agent_id)

		if "affinities" in agent and typeof(agent.affinities) == TYPE_DICTIONARY and agent.affinities.has(oid):
			return float(agent.affinities[oid])

		if "relationships" in agent and typeof(agent.relationships) == TYPE_DICTIONARY and agent.relationships.has(oid):
			var rel: Dictionary = agent.relationships[oid]
			var aff01: float = float(rel.get("affinity", 0.5))
			return (aff01 * 2.0) - 1.0

	return 0.0

# =====================================================
# SELECCIÓN ALEATORIA
# =====================================================

func _random_agent(agent: Agent, all_agents: Array[Agent]) -> Agent:
	var candidates: Array[Agent] = []
	for a in all_agents:
		if a == null or not is_instance_valid(a):
			continue
		if a != agent:
			candidates.append(a)

	if candidates.is_empty():
		return null

	return candidates[randi() % candidates.size()]
