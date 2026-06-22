extends Node
class_name SaveSystem

var save_path := "user://save_01.json"

func save_game(agents: Array[Agent]) -> void:

	var save_data: Dictionary = {}
	var agent_list: Array = []

	for agent in agents:
		agent_list.append({
			"name": agent.get_agent_name(),
			"position": agent.global_position,
			"mood": agent.mood,
			"relationships": agent.relationships,
			"memory": agent.long_memory,
			"existential_state": agent.existential_state
		})

	save_data["agents"] = agent_list

	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()


func load_game() -> Dictionary:

	if not FileAccess.file_exists(save_path):
		return {}

	var file = FileAccess.open(save_path, FileAccess.READ)
	var content = file.get_as_text()
	file.close()

	return JSON.parse_string(content)
