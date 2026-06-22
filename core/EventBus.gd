extends Node

@export var debug_print: bool = false
@export var max_log_events: int = 250

var log_history: Array[String] = []

signal agent_hovered(agent)
signal agent_unhovered(agent)
signal agent_clicked(agent)

signal agent_selected(agent)
signal agent_deselected()

signal request_follow(agent)
signal request_stop_follow()

signal log_event(text: String)
signal toast(text: String, kind: String)

signal social_interaction(a, b, affinity_delta: float)
signal mood_changed(agent, key: String, new_value: float)
signal need_changed(agent, key: String, new_value: float)

signal thought_generated(agent, text: String)
signal thought_clicked(agent, text: String)

signal activity_logged(agent, entry: Dictionary)

func _ready() -> void:
	if debug_print:
		print("EventBus listo (autoload).")

func emit_agent_hovered(agent) -> void:
	agent_hovered.emit(agent)

func emit_agent_unhovered(agent) -> void:
	agent_unhovered.emit(agent)

func emit_agent_clicked(agent) -> void:
	agent_clicked.emit(agent)

func emit_agent_selected(agent) -> void:
	agent_selected.emit(agent)

func emit_agent_deselected() -> void:
	agent_deselected.emit()

func emit_follow(agent) -> void:
	request_follow.emit(agent)

func emit_unfollow() -> void:
	request_stop_follow.emit()

func emit_log(text: String) -> void:
	if text == null:
		return
	var t: String = str(text).strip_edges()
	if t == "":
		return

	log_history.append(t)
	if log_history.size() > max_log_events:
		log_history.pop_front()

	log_event.emit(t)

	if debug_print:
		print("[LOG] ", t)

func emit_toast(text: String, kind: String = "info") -> void:
	if text == null:
		return
	var t: String = str(text).strip_edges()
	if t == "":
		return
	toast.emit(t, kind)
	if debug_print:
		print("[TOAST %s] %s" % [kind, t])

func clear_log_history() -> void:
	log_history.clear()

func emit_social_interaction(a, b, affinity_delta: float) -> void:
	social_interaction.emit(a, b, affinity_delta)

func emit_mood_changed(agent, key: String, new_value: float) -> void:
	mood_changed.emit(agent, key, new_value)

func emit_need_changed(agent, key: String, new_value: float) -> void:
	need_changed.emit(agent, key, new_value)

func emit_thought_generated(agent, text: String) -> void:
	var t: String = str(text).strip_edges()
	thought_generated.emit(agent, t)
	emit_log("🧠 %s pensó: %s" % [_safe_agent_name(agent), t])

func emit_thought_clicked(agent, text: String) -> void:
	var t: String = str(text).strip_edges()
	thought_clicked.emit(agent, t)

func emit_activity_logged(agent, entry: Dictionary) -> void:
	activity_logged.emit(agent, entry)

func _safe_agent_name(agent) -> String:
	if agent == null:
		return "Agente"
	if agent.has_method("get_agent_name"):
		return str(agent.call("get_agent_name"))
	if "name" in agent:
		return str(agent.name)
	return "Agente"
