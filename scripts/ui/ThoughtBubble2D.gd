extends Node2D
class_name ThoughtBubble2D

@export var lifetime: float = 10.0
@export var float_speed: float = 12.0
@export var rise_pixels: float = 26.0

var agent: Agent = null
var thought_text: String = ""

var _panel: PanelContainer
var _label: Label
var _age: float = 0.0
var _start_y: float = 0.0

func _ready() -> void:
	_build()
	_start_y = position.y

func setup(a: Agent, text: String) -> void:
	agent = a
	thought_text = text
	if is_instance_valid(_label):
		_label.text = "💭"
		_label.tooltip_text = thought_text

func _build() -> void:
	_panel = PanelContainer.new()
	add_child(_panel)

	_panel.mouse_filter = Control.MOUSE_FILTER_PASS

	_label = Label.new()
	_label.text = "💭"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.custom_minimum_size = Vector2(34, 26)
	_panel.add_child(_label)

	_panel.gui_input.connect(_on_gui_input)

func _on_gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb: InputEventMouseButton = ev as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			# Al click: selecciona agente y abre el panel con el pensamiento
			if Engine.has_singleton("EventBus"):
				if agent != null and is_instance_valid(agent):
					EventBus.emit_agent_selected(agent)
					EventBus.emit_toast("💭 " + agent.get_agent_name())
			queue_free()
			get_viewport().set_input_as_handled()

func _process(dt: float) -> void:
	_age += dt
	position.y = lerpf(_start_y, _start_y - rise_pixels, clamp(_age / max(lifetime, 0.01), 0.0, 1.0))
	position.y -= sin(_age * 2.0) * (float_speed * 0.08)

	if _age >= lifetime:
		queue_free()
