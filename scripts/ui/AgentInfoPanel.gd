extends PanelContainer
class_name AgentInfoPanel

@export var refresh_rate: float = 0.75

var _agent: Agent = null
var _timer: Timer

# Main scroll/root
var _main_scroll: ScrollContainer
var _root: VBoxContainer

# Header
var _header: HBoxContainer
var _portrait: TextureRect
var _header_text: VBoxContainer
var _name_label: Label
var _meta_label: Label
var _goal_label: Label
var _activity_label: Label

# Tabs
var _tabs: TabContainer

# Tab: Agente
var _agent_tab_box: VBoxContainer
var _agent_summary_label: RichTextLabel

# Tab: Estado
var _state_tab_box: HBoxContainer
var _mood_box: VBoxContainer
var _needs_box: VBoxContainer

# Tab: Plan
var _plan_tab_box: VBoxContainer
var _plan_timeline_title: Label
var _plan_scroll: ScrollContainer
var _plan_timeline_box: VBoxContainer

# Tab: Memorias
var _memory_tab_box: VBoxContainer
var _memory_box: VBoxContainer

# cache
var _last_agent_id: String = ""
var _last_meta_text: String = ""
var _last_goal_text: String = ""
var _last_activity_text: String = ""
var _last_summary_text: String = ""
var _last_memory_signature: String = ""
var _last_plan_signature: String = ""
var _last_mood_signature: String = ""
var _last_needs_signature: String = ""

func _ready() -> void:
	custom_minimum_size = Vector2(360, 540)
	_build_ui()

	_timer = Timer.new()
	_timer.one_shot = false
	_timer.wait_time = max(0.2, refresh_rate)
	_timer.timeout.connect(_refresh)
	add_child(_timer)

	_clear_ui()

func set_agent(agent: Agent) -> void:
	if is_instance_valid(_timer):
		_timer.stop()

	var new_id: String = _get_agent_id_string(agent)

	if _agent != null and is_instance_valid(_agent) and new_id == _last_agent_id:
		_agent = agent
		_refresh()
		if is_instance_valid(_timer):
			_timer.start()
		return

	_agent = agent
	_reset_caches()

	if _agent == null or not is_instance_valid(_agent):
		clear_agent()
		return

	_refresh()

	if is_instance_valid(_timer):
		_timer.start()

func clear_agent() -> void:
	if is_instance_valid(_timer):
		_timer.stop()

	_agent = null
	_reset_caches()
	_clear_ui()

# =====================================================
# UI BUILD
# =====================================================

func _build_ui() -> void:
	_main_scroll = ScrollContainer.new()
	_main_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_main_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(_main_scroll)

	_root = VBoxContainer.new()
	_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_root.add_theme_constant_override("separation", 8)
	_main_scroll.add_child(_root)

	# Header
	_header = HBoxContainer.new()
	_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_theme_constant_override("separation", 10)
	_root.add_child(_header)

	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(72, 72)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_header.add_child(_portrait)

	_header_text = VBoxContainer.new()
	_header_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_text.add_theme_constant_override("separation", 2)
	_header.add_child(_header_text)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 18)
	_header_text.add_child(_name_label)

	_meta_label = Label.new()
	_meta_label.modulate = Color(1, 1, 1, 0.78)
	_meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_header_text.add_child(_meta_label)

	_goal_label = Label.new()
	_goal_label.modulate = Color(1, 1, 1, 0.95)
	_goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_header_text.add_child(_goal_label)

	_activity_label = Label.new()
	_activity_label.modulate = Color(1, 1, 1, 0.82)
	_activity_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_header_text.add_child(_activity_label)

	_root.add_child(HSeparator.new())

	_tabs = TabContainer.new()
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.add_child(_tabs)

	# -------- Tab Agente
	_agent_tab_box = VBoxContainer.new()
	_agent_tab_box.name = "Agente"
	_agent_tab_box.add_theme_constant_override("separation", 8)
	_tabs.add_child(_agent_tab_box)

	_agent_summary_label = RichTextLabel.new()
	_agent_summary_label.bbcode_enabled = true
	_agent_summary_label.fit_content = true
	_agent_summary_label.scroll_active = false
	_agent_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_agent_tab_box.add_child(_agent_summary_label)

	# -------- Tab Estado
	_state_tab_box = HBoxContainer.new()
	_state_tab_box.name = "Estado"
	_state_tab_box.add_theme_constant_override("separation", 6)
	_tabs.add_child(_state_tab_box)

	var mood_col := VBoxContainer.new()
	mood_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mood_col.add_theme_constant_override("separation", 4)
	_state_tab_box.add_child(mood_col)

	var mood_title := Label.new()
	mood_title.text = "Mood"
	mood_title.add_theme_font_size_override("font_size", 14)
	mood_col.add_child(mood_title)

	_mood_box = VBoxContainer.new()
	_mood_box.add_theme_constant_override("separation", 3)
	mood_col.add_child(_mood_box)

	var needs_col := VBoxContainer.new()
	needs_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	needs_col.add_theme_constant_override("separation", 4)
	_state_tab_box.add_child(needs_col)

	var needs_title := Label.new()
	needs_title.text = "Needs"
	needs_title.add_theme_font_size_override("font_size", 14)
	needs_col.add_child(needs_title)

	_needs_box = VBoxContainer.new()
	_needs_box.add_theme_constant_override("separation", 3)
	needs_col.add_child(_needs_box)

	# -------- Tab Plan
	_plan_tab_box = VBoxContainer.new()
	_plan_tab_box.name = "Plan"
	_plan_tab_box.add_theme_constant_override("separation", 8)
	_tabs.add_child(_plan_tab_box)

	_plan_timeline_title = Label.new()
	_plan_timeline_title.text = "Horario del día"
	_plan_timeline_title.add_theme_font_size_override("font_size", 14)
	_plan_tab_box.add_child(_plan_timeline_title)

	_plan_scroll = ScrollContainer.new()
	_plan_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_plan_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_plan_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_plan_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_plan_tab_box.add_child(_plan_scroll)

	_plan_timeline_box = VBoxContainer.new()
	_plan_timeline_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_plan_timeline_box.add_theme_constant_override("separation", 6)
	_plan_scroll.add_child(_plan_timeline_box)

	# -------- Tab Memorias
	_memory_tab_box = VBoxContainer.new()
	_memory_tab_box.name = "Memorias"
	_memory_tab_box.add_theme_constant_override("separation", 8)
	_tabs.add_child(_memory_tab_box)

	_memory_box = VBoxContainer.new()
	_memory_box.add_theme_constant_override("separation", 4)
	_memory_tab_box.add_child(_memory_box)

# =====================================================
# REFRESH
# =====================================================

func _refresh() -> void:
	if _agent == null or not is_instance_valid(_agent):
		clear_agent()
		return

	var agent_id: String = _get_agent_id_string(_agent)
	_last_agent_id = agent_id

	var nm: String = _agent.get_agent_name()
	var g: String = _agent.get_gender()

	var name_text: String = "🧍 %s%s" % [nm, ((" (" + g + ")") if g != "" else "")]
	if _name_label.text != name_text:
		_name_label.text = name_text

	var meta_text: String = "pos: (%.1f, %.1f) • moving: %s • awaiting: %s" % [
		_agent.global_position.x,
		_agent.global_position.y,
		str(_agent.moving),
		str(_agent.awaiting_thought)
	]
	if meta_text != _last_meta_text:
		_last_meta_text = meta_text
		_meta_label.text = meta_text

	var portrait: Texture2D = _agent.get_portrait_texture()
	if _portrait.texture != portrait:
		_portrait.texture = portrait

	var goal: String = _agent.current_goal_label
	if goal == "":
		goal = "Sin objetivo (idle)"
	var goal_text: String = "🎯 " + goal
	if goal_text != _last_goal_text:
		_last_goal_text = goal_text
		_goal_label.text = goal_text

	var act: String = ""
	if "current_activity" in _agent:
		act = str(_agent.get("current_activity")).strip_edges()
	var activity_text: String = ("🧩 " + act) if act != "" else ""
	if activity_text != _last_activity_text:
		_last_activity_text = activity_text
		_activity_label.text = activity_text

	var summary_text: String = _build_agent_summary_bbcode()
	if summary_text != _last_summary_text:
		_last_summary_text = summary_text
		_agent_summary_label.text = summary_text

	var mood_sig: String = _dict_signature(_agent.mood, ["happiness", "loneliness", "anxiety", "stress", "anger"])
	if mood_sig != _last_mood_signature:
		_last_mood_signature = mood_sig
		_build_bars(_mood_box, _agent.mood, ["happiness", "loneliness", "anxiety", "stress", "anger"])

	var needs_sig: String = _dict_signature(_agent.needs, ["social", "curiosity"])
	if needs_sig != _last_needs_signature:
		_last_needs_signature = needs_sig
		_build_bars(_needs_box, _agent.needs, ["social", "curiosity"])

	var plan_sig: String = _plan_signature()
	if plan_sig != _last_plan_signature:
		_last_plan_signature = plan_sig
		_build_plan()

	var mem_sig: String = _memory_signature()
	if mem_sig != _last_memory_signature:
		_last_memory_signature = mem_sig
		_build_memories()

# =====================================================
# BUILDERS
# =====================================================

func _build_agent_summary_bbcode() -> String:
	if _agent == null or not is_instance_valid(_agent):
		return "[i](sin agente)[/i]"

	var lines: Array[String] = []

	lines.append("[b]Nombre:[/b] " + _bb(_agent.get_agent_name()))

	var gender: String = _agent.get_gender()
	lines.append("[b]Género:[/b] " + _bb(gender if gender != "" else "No definido"))

	if _agent.data != null and typeof(_agent.data.personality) == TYPE_DICTIONARY:
		var p: Dictionary = _agent.data.personality
		lines.append("")
		lines.append("[b]Personalidad[/b]")
		lines.append("• Introspección: %d%%" % int(round(_safe_float_from_variant(p.get("introspection", 0.5), 0.5) * 100.0)))
		lines.append("• Sociabilidad: %d%%" % int(round(_safe_float_from_variant(p.get("sociability", 0.5), 0.5) * 100.0)))
		lines.append("• Estabilidad: %d%%" % int(round(_safe_float_from_variant(p.get("stability", 0.5), 0.5) * 100.0)))

	var thought: String = _get_last_real_thought(_agent)
	lines.append("")
	lines.append("[b]Último pensamiento[/b]")
	lines.append(_bb(thought if thought != "" else "(aún no hay pensamiento de Ollama)"))

	return "\n".join(lines)

func _build_bars(parent_box: VBoxContainer, dict: Dictionary, keys: Array) -> void:
	_clear_children(parent_box)

	if dict == null or dict.size() == 0:
		var t := Label.new()
		t.text = "(sin datos)"
		parent_box.add_child(t)
		return

	for k in keys:
		var v: float = clampf(_safe_float_from_variant(dict.get(k, 0.0), 0.0), 0.0, 1.0)
		parent_box.add_child(_bar_row(str(k), v))

func _bar_row(label_text: String, value01: float) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 1)

	var lbl := Label.new()
	lbl.text = "%s: %d%%" % [label_text, int(round(value01 * 100.0))]
	row.add_child(lbl)

	var pb := ProgressBar.new()
	pb.min_value = 0.0
	pb.max_value = 1.0
	pb.value = value01
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pb.custom_minimum_size = Vector2(0, 6)
	pb.show_percentage = false
	row.add_child(pb)

	return row

func _build_plan() -> void:
	_clear_children(_plan_timeline_box)

	if _agent == null or not is_instance_valid(_agent):
		return

	var plan_arr: Array = []
	if "today_plan" in _agent and typeof(_agent.today_plan) == TYPE_ARRAY:
		plan_arr = _agent.today_plan

	if plan_arr.is_empty():
		var t := Label.new()
		t.text = "(sin agenda aún)"
		_plan_timeline_box.add_child(t)
		return

	var hours: Array[String] = ["07:00 - 09:00", "09:00 - 12:00", "12:00 - 16:00", "16:00 - 21:00"]

	for i in range(plan_arr.size()):
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_plan_timeline_box.add_child(card)

		var inner := VBoxContainer.new()
		inner.add_theme_constant_override("separation", 2)
		card.add_child(inner)

		var top := Label.new()
		top.modulate = Color(0.78, 0.95, 0.85, 1.0)

		var title_text: String = ""
		var detail_text: String = ""

		if typeof(plan_arr[i]) == TYPE_DICTIONARY:
			var d: Dictionary = plan_arr[i]
			title_text = str(d.get("title", "(sin título)")).strip_edges()
			detail_text = str(d.get("detail", "")).strip_edges()
		else:
			title_text = str(plan_arr[i]).strip_edges()

		top.text = hours[min(i, hours.size() - 1)]
		inner.add_child(top)

		var title := Label.new()
		title.text = title_text if title_text != "" else "(sin título)"
		title.add_theme_font_size_override("font_size", 18)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inner.add_child(title)

		if detail_text != "":
			var detail := Label.new()
			detail.text = detail_text
			detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			detail.modulate = Color(0.9, 0.9, 0.9, 1.0)
			inner.add_child(detail)

func _build_memories() -> void:
	_clear_children(_memory_box)

	if _agent == null or not is_instance_valid(_agent):
		return

	if _agent.long_memory == null or _agent.long_memory.is_empty():
		var t := Label.new()
		t.text = "(sin memorias aún)"
		_memory_box.add_child(t)
		return

	var shown: int = 0
	for i in range(_agent.long_memory.size() - 1, -1, -1):
		var item: Variant = _agent.long_memory[i]
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var d: Dictionary = item
		var txt: String = str(d.get("text", "")).strip_edges()
		if txt == "":
			continue

		var typ: String = str(d.get("type", "evento")).strip_edges()

		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 1)
		_memory_box.add_child(row)

		var head := Label.new()
		head.text = "[%s]" % typ
		head.modulate = Color(0.95, 0.75, 0.45, 1.0)
		row.add_child(head)

		var body := Label.new()
		body.text = txt
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(body)

		row.add_child(HSeparator.new())

		shown += 1
		if shown >= 10:
			break

# =====================================================
# HELPERS
# =====================================================

func _get_last_real_thought(a: Agent) -> String:
	if a == null or not is_instance_valid(a):
		return ""

	if a.long_memory == null or a.long_memory.size() == 0:
		return ""

	for i in range(a.long_memory.size() - 1, -1, -1):
		var item: Variant = a.long_memory[i]
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var d: Dictionary = item
		var typ: String = str(d.get("type", ""))
		if typ == "thought":
			return str(d.get("text", "")).strip_edges()

	return ""

func _safe_float_from_variant(v: Variant, default_value: float = 0.0) -> float:
	if v == null:
		return default_value

	var t: int = typeof(v)
	if t == TYPE_FLOAT:
		return v
	if t == TYPE_INT:
		return float(v)
	if t == TYPE_STRING:
		return String(v).to_float()

	return default_value

func _bb(s: String) -> String:
	return s.replace("[", "\\[").replace("]", "\\]")

func _get_agent_id_string(agent: Agent) -> String:
	if agent == null or not is_instance_valid(agent):
		return ""
	if agent.data == null:
		return agent.get_agent_name()
	return str(agent.data.agent_id)

func _dict_signature(dict: Dictionary, keys: Array) -> String:
	if dict == null:
		return ""

	var parts: Array[String] = []
	for k in keys:
		parts.append("%s=%.4f" % [str(k), _safe_float_from_variant(dict.get(k, 0.0), 0.0)])

	return "|".join(parts)

func _plan_signature() -> String:
	if _agent == null or not is_instance_valid(_agent):
		return ""

	if not ("today_plan" in _agent) or typeof(_agent.today_plan) != TYPE_ARRAY:
		return ""

	var parts: Array[String] = []
	for it in _agent.today_plan:
		if typeof(it) == TYPE_DICTIONARY:
			var d: Dictionary = it
			parts.append("%s|%s|%s|%s" % [
				str(d.get("segment", "")),
				str(d.get("time_label", "")),
				str(d.get("title", "")),
				str(d.get("detail", ""))
			])
		else:
			parts.append(str(it))

	return "||".join(parts)

func _memory_signature() -> String:
	if _agent == null or not is_instance_valid(_agent):
		return ""

	if _agent.long_memory == null or _agent.long_memory.is_empty():
		return ""

	var parts: Array[String] = []
	var count: int = 0

	for i in range(_agent.long_memory.size() - 1, -1, -1):
		var item: Variant = _agent.long_memory[i]
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var d: Dictionary = item
		parts.append("%s|%s|%s" % [
			str(d.get("type", "")),
			str(d.get("text", "")),
			str(d.get("timestamp", ""))
		])

		count += 1
		if count >= 10:
			break

	return "||".join(parts)

func _clear_children(node: Node) -> void:
	for c in node.get_children():
		c.queue_free()

func _reset_caches() -> void:
	_last_agent_id = ""
	_last_meta_text = ""
	_last_goal_text = ""
	_last_activity_text = ""
	_last_summary_text = ""
	_last_memory_signature = ""
	_last_plan_signature = ""
	_last_mood_signature = ""
	_last_needs_signature = ""

func _clear_ui() -> void:
	_name_label.text = "Agente"
	_meta_label.text = ""
	_goal_label.text = "🎯 Sin objetivo"
	_activity_label.text = ""
	_portrait.texture = null
	_agent_summary_label.text = "[i](sin agente seleccionado)[/i]"

	_clear_children(_mood_box)
	_clear_children(_needs_box)
	_clear_children(_plan_timeline_box)
	_clear_children(_memory_box)
