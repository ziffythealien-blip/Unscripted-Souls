extends Node
class_name MemorySystem

func add_memory(agent: Agent, text: String):
	agent.long_memory.append({
		"text": text,
		"timestamp": Time.get_unix_time_from_system()
	})

func get_recent(agent: Agent, limit := 5):
	return agent.long_memory.slice(-limit, agent.long_memory.size())
