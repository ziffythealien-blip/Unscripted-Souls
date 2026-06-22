extends Resource
class_name AgentData

# =====================================================
# IDENTIDAD
# =====================================================

@export var agent_id: String = ""
@export var agent_name: String = ""
@export var age: int = 18
@export var gender: String = "male"
@export var sprite_variant: int = 0

# =====================================================
# PERSONALIDAD
# =====================================================

@export var personality: Dictionary = {
	"introspection": 0.5,
	"sociability": 0.5,
	"stability": 0.5
}

@export var background_seed: int = 0


# =====================================================
# INIT
# =====================================================

func _init() -> void:

	if background_seed == 0:
		background_seed = randi()

	if agent_id == "":
		_generate_unique_id()

	_validate_personality()


# =====================================================
# ID GENERATION
# =====================================================

func _generate_unique_id() -> void:
	agent_id = str(Time.get_unix_time_from_system()) + "_" + str(randi())


# =====================================================
# PERSONALITY VALIDATION
# =====================================================

func _validate_personality() -> void:

	if personality == null:
		personality = {}

	if not personality.has("introspection"):
		personality["introspection"] = 0.5

	if not personality.has("sociability"):
		personality["sociability"] = 0.5

	if not personality.has("stability"):
		personality["stability"] = 0.5

	personality["introspection"] = clamp(float(personality["introspection"]), 0.0, 1.0)
	personality["sociability"] = clamp(float(personality["sociability"]), 0.0, 1.0)
	personality["stability"] = clamp(float(personality["stability"]), 0.0, 1.0)


# =====================================================
# TRAIT ACCESS
# =====================================================

func get_trait(trait_name: String, default_value: float = 0.5) -> float:
	return float(personality.get(trait_name, default_value))


func set_trait(trait_name: String, value: float) -> void:
	personality[trait_name] = clamp(value, 0.0, 1.0)


# =====================================================
# SERIALIZACIÓN
# =====================================================

func to_dict() -> Dictionary:
	return {
		"agent_id": agent_id,
		"agent_name": agent_name,
		"age": age,
		"gender": gender,
		"sprite_variant": sprite_variant,
		"personality": personality,
		"background_seed": background_seed
	}


func from_dict(data: Dictionary) -> void:

	agent_id = data.get("agent_id", "")
	agent_name = data.get("agent_name", "")
	age = data.get("age", 18)
	gender = data.get("gender", "male")
	sprite_variant = data.get("sprite_variant", 0)
	personality = data.get("personality", {})
	background_seed = data.get("background_seed", randi())

	if agent_id == "":
		_generate_unique_id()

	_validate_personality()
