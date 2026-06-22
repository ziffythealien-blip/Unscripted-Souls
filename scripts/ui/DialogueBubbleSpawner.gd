# res://scripts/ui/DialogueBubbleSpawner.gd
extends CanvasLayer
class_name DialogueBubbleSpawner

@export var y_offset: float = -34.0
@export var lifetime_sec: float = 3.2
@export var fade_time_sec: float = 0.25
@export var float_up_px: float = 22.0

@export var max_active_per_agent: int = 2
@export var font_size: int = 14

# agent_id -> Array[Control] (burbujas activas)
var _active: Dictionary = {}


func _ready() -> void:
	layer = 60

	if Engine.has_singleton("EventBus"):
		if EventBus.has_signal("thought_generated") and not EventBus.thought_generated.is_connected(_on_thought):
			EventBus.thought_generated.connect(_on_thought)

		# Opcional: burbuja mini cuando el agente responde en chat
		if EventBus.has_signal("chat_message") and not EventBus.chat_message.is_connected(_on_chat_message):
			EventBus.chat_message.connect(_on_chat_message)


func _on_thought(agent: Agent, text: String) -> void:
	if agent == null or not is_instance_valid(agent):
		return
	var t := str(text).strip_edges()
	if t == "":
		return
	_spawn(agent, "🧠 " + t)


func _on_chat_message(agent: Agent, role: String, text: String) -> void:
	if agent == null or not is_instance_valid(agent):
		return
	if str(role) != "agent":
		return
	var t := str(text).strip_edges()
	if t == "":
		return
	# más corto para no tapar pantalla
	var short := t
	if short.length() > 64:
		short = short.substr(0, 64) + "…"
	_spawn(agent, "💬 " + short)


func _spawn(agent: Agent, msg: String) -> void:
	var aid: String = _agent_key(agent)

	# Limitar burbujas por agente
	var arr: Array = _active.get(aid, [])
	_prune_dead(arr)
	while arr.size() >= max_active_per_agent:
		var old: Control = arr.pop_front()
		if is_instance_valid(old):
			old.queue_free()

	# Panel burbuja
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	var lbl := Label.new()
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.text = msg
	lbl.add_theme_font_size_override("font_size", font_size)
	panel.add_child(lbl)

	# Posicionar
	panel.global_position = agent.global_position + Vector2(0.0, y_offset)

	# Anim: fade in + float
	panel.modulate.a = 0.0
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, fade_time_sec)
	tw.parallel().tween_property(panel, "position:y", panel.position.y - float_up_px, lifetime_sec)

	# Espera, fade out, cleanup
	var tmr := Timer.new()
	tmr.one_shot = true
	tmr.wait_time = max(0.3, lifetime_sec)
	tmr.timeout.connect(func() -> void:
		if not is_instance_valid(panel):
			tmr.queue_free()
			return
		var tw2 := create_tween()
		tw2.set_trans(Tween.TRANS_SINE)
		tw2.set_ease(Tween.EASE_IN)
		tw2.tween_property(panel, "modulate:a", 0.0, fade_time_sec)
		tw2.finished.connect(func() -> void:
			if is_instance_valid(panel):
				panel.queue_free()
			tmr.queue_free()
		)
	)
	add_child(tmr)
	tmr.start()

	arr.append(panel)
	_active[aid] = arr


func _prune_dead(arr: Array) -> void:
	var cleaned: Array = []
	for n in arr:
		if is_instance_valid(n):
			cleaned.append(n)
	arr.clear()
	for n2 in cleaned:
		arr.append(n2)


func _agent_key(agent: Agent) -> String:
	if agent == null or not is_instance_valid(agent) or agent.data == null:
		return "unknown"
	return str(agent.data.agent_id)
