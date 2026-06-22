extends Node
class_name RelationshipSystem

func ensure_relationship(agent: Agent, other_id: String):
	if not agent.relationships.has(other_id):
		agent.relationships[other_id] = {
			"trust": 0.5,
			"resentment": 0.0,
			"affinity": 0.5
		}

func apply_interaction(a: Agent, b: Agent, positive: bool):
	ensure_relationship(a, b.data.id)
	ensure_relationship(b, a.data.id)
	
	if positive:
		a.relationships[b.data.id]["trust"] += 0.1
		b.relationships[a.data.id]["trust"] += 0.1
	else:
		a.relationships[b.data.id]["resentment"] += 0.3
		b.relationships[a.data.id]["resentment"] += 0.3
		a.mood["anger"] += 0.2
		b.mood["anger"] += 0.2
