extends PanelContainer
class_name ActivityLogPanel

@export var max_items: int = 40

var _agent: Agent = null
var _scroll: ScrollContainer
var _list: VBoxContainer

func _ready() -> void:
	custom_minimum_size = Vector2(0, 280)
	_build_ui()

func set_agent(agent: Agent) -> void:
	_agent = agent
	refresh_view()

func refresh_view() -> void:
	for c in _list.get_children():
		c.queue_free()

	if _agent == null or not is_instance_valid(_agent):
		_add_empty("(sin agente)")
		return

	if _agent.long_memory == null or _agent.long_memory.is_empty():
		_add_empty("(sin actividad aún)")
		return

	var shown: int = 0
	for i in range(_agent.long_memory.size() - 1, -1, -1):
		var item: Variant = _agent.long_memory[i]
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var d: Dictionary = item
		var typ: String = str(d.get("type", "event"))
		if typ != "activity" and typ != "event" and typ != "chat":
			continue

		var text: String = str(d.get("text", "")).strip_edges()
		if text == "":
			continue

		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		_list.add_child(row)

		var head := Label.new()
		head.text = _format_head(d, typ)
		head.modulate = Color(1, 1, 1, 0.72)
		row.add_child(head)

		var body := Label.new()
		body.text = text
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(body)

		row.add_child(HSeparator.new())

		shown += 1
		if shown >= max_items:
			break

	if shown == 0:
		_add_empty("(sin actividad aún)")

func _build_ui() -> void:
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(_scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_list.add_theme_constant_override("separation", 6)
	_scroll.add_child(_list)

func _add_empty(txt: String) -> void:
	var lbl := Label.new()
	lbl.text = txt
	lbl.modulate = Color(1, 1, 1, 0.65)
	_list.add_child(lbl)

func _format_head(d: Dictionary, typ: String) -> String:
	var stamp: String = ""
	if d.has("timestamp"):
		stamp = _timestamp_to_text(int(d.get("timestamp", 0)))
	var where: String = str(d.get("location", "")).strip_edges()

	var type_label: String = typ.capitalize()
	if where != "":
		return "%s · %s · %s" % [stamp, type_label, where]
	return "%s · %s" % [stamp, type_label]

func _timestamp_to_text(ts: int) -> String:
	if ts <= 0:
		return "--:--"
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(ts)
	return "%02d:%02d" % [int(dt.get("hour", 0)), int(dt.get("minute", 0))]
