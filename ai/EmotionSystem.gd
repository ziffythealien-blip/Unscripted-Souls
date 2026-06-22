extends Node
class_name EmotionSystem

func daily_update(agent: Agent) -> void:
	if agent == null or not is_instance_valid(agent):
		return

	# Asegura mood aunque el agente venga raro
	if agent.mood == null:
		agent.mood = {}

	if not agent.mood.has("anger"):
		agent.mood["anger"] = 0.0
	if not agent.mood.has("happiness"):
		agent.mood["happiness"] = 0.5
	if not agent.mood.has("loneliness"):
		agent.mood["loneliness"] = 0.2
	if not agent.mood.has("anxiety"):
		agent.mood["anxiety"] = 0.1

	agent.mood["anger"] = float(agent.mood["anger"]) * 0.90
	agent.mood["happiness"] = float(agent.mood["happiness"]) * 0.98
	agent.mood["loneliness"] = float(agent.mood["loneliness"]) + 0.01
	agent.mood["anxiety"] = float(agent.mood["anxiety"]) * 0.99

	_clamp_mood(agent)


func _clamp_mood(agent: Agent) -> void:
	for k in agent.mood.keys():
		agent.mood[k] = clamp(float(agent.mood[k]), 0.0, 1.0)
