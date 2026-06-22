extends Node
class_name PromptBuilder

func build(agent: Agent) -> String:
	var text = "Estado emocional:\n"
	text += str(agent.mood) + "\n"
	text += "Relaciones:\n"
	text += str(agent.relationships) + "\n"
	text += "Recuerdos recientes:\n"
	text += str(agent.long_memory)
	return text
