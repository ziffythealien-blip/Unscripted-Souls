extends Node
class_name CameraFollow

@export var follow_lerp: float = 8.0

@onready var cam: Camera2D = get_tree().get_root().find_child("Camera2D", true, false) as Camera2D

var _target: Agent = null

# overlay
var _layer: CanvasLayer
var _label: Label

func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 200
	add_child(_layer)

	_label = Label.new()
	_label.text = ""
	_label.visible = false
	_label.add_theme_font_size_override("font_size", 16)
	_layer.add_child(_label)

	if Engine.has_singleton("EventBus"):
		EventBus.request_follow.connect(func(a: Agent) -> void:
			_target = a
			_label.visible = (_target != null)
		)
		EventBus.request_stop_follow.connect(func() -> void:
			_target = null
			_label.visible = false
		)

func _process(delta: float) -> void:
	if cam == null or _target == null or not is_instance_valid(_target):
		return

	# follow
	var desired: Vector2 = _target.global_position
	cam.global_position = cam.global_position.lerp(desired, clamp(delta * follow_lerp, 0.0, 1.0))

	# label + flecha simple
	var screen_pos: Vector2 = cam.get_viewport().get_camera_2d().unproject_position(_target.global_position)
	_label.text = "⬇ " + _target.get_agent_name()
	_label.position = screen_pos + Vector2(10, -30)
