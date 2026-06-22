extends Node2D
class_name ThoughtBubbleSpawner

static func ensure_exists(tree: SceneTree) -> ThoughtBubbleSpawner:
	if tree == null:
		return null

	var root_scene: Node = tree.current_scene
	if root_scene == null:
		root_scene = tree.get_root()

	var found: ThoughtBubbleSpawner = root_scene.find_child("ThoughtBubbleSpawner", true, false) as ThoughtBubbleSpawner
	if found != null:
		return found

	var sp: ThoughtBubbleSpawner = ThoughtBubbleSpawner.new()
	sp.name = "ThoughtBubbleSpawner"
	root_scene.add_child(sp)
	return sp

@export var bubble_scene_path: String = "" # opcional si quieres .tscn, si no, crea runtime

func _ready() -> void:
	if Engine.has_singleton("EventBus"):
		if not EventBus.thought_generated.is_connected(_on_thought_generated):
			EventBus.thought_generated.connect(_on_thought_generated)

func _on_thought_generated(agent: Agent, text: String) -> void:
	if agent == null or not is_instance_valid(agent):
		return

	var bubble: ThoughtBubble2D = _make_bubble()
	if bubble == null:
		return

	add_child(bubble)
	bubble.global_position = agent.global_position + Vector2(0, -24)
	bubble.setup(agent, text)

func _make_bubble() -> ThoughtBubble2D:
	if bubble_scene_path.strip_edges() != "":
		var ps: PackedScene = load(bubble_scene_path) as PackedScene
		if ps != null:
			return ps.instantiate() as ThoughtBubble2D
	return ThoughtBubble2D.new()
