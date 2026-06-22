extends Node2D
class_name Location

@export var location_name: String = "Park"
@export var location_type: String = "park"

@export var reduces_anxiety: float = 0.1
@export var increases_happiness: float = 0.1
@export var social_probability: float = 0.3

func apply_effects(agent):
	if agent == null:
		return
	
	agent.mood += increases_happiness
	agent.anxiety -= reduces_anxiety
	
	agent.mood = clamp(agent.mood, -1.0, 1.0)
	agent.anxiety = clamp(agent.anxiety, 0.0, 1.0)
