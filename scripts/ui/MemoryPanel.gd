extends PanelContainer
class_name MemoryPanel

@export var max_items: int = 60

var _agent: Agent = null
var _current_filter: String = "all"

var _root: VBoxContainer
var _filters: HBoxContainer
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
		_add_empty("(sin memorias)")
		return

	var shown: int = 0
	for i in range(_agent.long_memory.size() - 1, -1, -1):
		var item: Variant = _agent.long_memory[i]
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var d: Dictionary = item
		var typ: String = str(d.get("type", "event"))
		if not _passes_filter(typ):
			continue

		var text: String = str(d.get("text", "")).strip_edges()
		if text == "":
			continue

		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 3)
		_list.add_child(card)

		var head := Label.new()
		head.text = "%s · %s" % [_timestamp_to_text(int(d.get("timestamp", 0))), typ.capitalize()]
		head.modulate = Color(1, 1, 1, 0.72)
		card.add_child(head)

		var body := Label.new()
		body.text = text
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(body)

		card.add_child(HSeparator.new())

		shown += 1
		if shown >= max_items:
			break

	if shown == 0:
		_add_empty("(sin memorias para ese filtro)")

func _build_ui() -> void:
	_root = VBoxContainer.new()
	_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.add_theme_constant_override("separation", 6)
	add_child(_root)

	_filters = HBoxContainer.new()
	_filters.add_theme_constant_override("separation", 6)
	_root.add_child(_filters)

	_add_filter_button("All", "all")
	_add_filter_button("Event", "event")
	_add_filter_button("Thought", "thought")
	_add_filter_button("Chat", "chat")
	_add_filter_button("Activity", "activity")

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_root.add_child(_scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_list.add_theme_constant_override("separation", 6)
	_scroll.add_child(_list)

func _add_filter_button(caption: String, filter_key: String) -> void:
	var btn := Button.new()
	btn.text = caption
	btn.pressed.connect(func() -> void:
		_current_filter = filter_key
		refresh_view()
	)
	_filters.add_child(btn)

func _add_empty(txt: String) -> void:
	var lbl := Label.new()
	lbl.text = txt
	lbl.modulate = Color(1, 1, 1, 0.65)
	_list.add_child(lbl)

func _passes_filter(typ: String) -> bool:
	if _current_filter == "all":
		return true
	return typ == _current_filter

func _timestamp_to_text(ts: int) -> String:
	if ts <= 0:
		return "--:--"
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(ts)
	return "%02d:%02d" % [int(dt.get("hour", 0)), int(dt.get("minute", 0))]
