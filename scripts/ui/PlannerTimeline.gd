extends PanelContainer
class_name PlannerTimeline

@export var start_hour: int = 6
@export var end_hour: int = 24
@export var hour_row_height: float = 56.0
@export var left_gutter_width: float = 74.0
@export var card_margin_x: float = 10.0
@export var card_inner_pad: int = 8
@export var red_line_height: float = 3.0
@export var auto_follow_now: bool = true

var _agent: Agent = null
var _scroll: ScrollContainer
var _content: Control
var _hours_layer: Control
var _cards_layer: Control
var _now_line: ColorRect

var _last_plan_signature: String = ""

func _ready() -> void:
	custom_minimum_size = Vector2(0, 420)
	_build_ui()
	_update_timeline_geometry()

func set_agent(agent: Agent) -> void:
	_agent = agent
	_rebuild_if_needed(true)
	_update_now_line()

func refresh_view() -> void:
	_rebuild_if_needed(false)
	_update_now_line()

func _build_ui() -> void:
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(_scroll)

	_content = Control.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.custom_minimum_size = Vector2(0, maxf(200.0, float(end_hour - start_hour) * hour_row_height))
	_scroll.add_child(_content)

	_hours_layer = Control.new()
	_hours_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hours_layer.anchor_right = 1.0
	_hours_layer.anchor_bottom = 1.0
	_content.add_child(_hours_layer)

	_cards_layer = Control.new()
	_cards_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cards_layer.anchor_right = 1.0
	_cards_layer.anchor_bottom = 1.0
	_content.add_child(_cards_layer)

	_now_line = ColorRect.new()
	_now_line.color = Color(0.9, 0.15, 0.15, 1.0)
	_now_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_now_line)

func _update_timeline_geometry() -> void:
	if _content == null:
		return
	_content.custom_minimum_size.y = float(max(1, end_hour - start_hour)) * hour_row_height
	_content.custom_minimum_size.x = 600.0
	_draw_hour_markers()

func _draw_hour_markers() -> void:
	for c in _hours_layer.get_children():
		c.queue_free()

	for hour in range(start_hour, end_hour):
		var row_y: float = float(hour - start_hour) * hour_row_height

		var hour_label := Label.new()
		hour_label.text = "%02d:00" % hour
		hour_label.position = Vector2(8.0, row_y - 8.0)
		hour_label.modulate = Color(1, 1, 1, 0.78)
		_hours_layer.add_child(hour_label)

		var sep := ColorRect.new()
		sep.color = Color(1, 1, 1, 0.08)
		sep.position = Vector2(left_gutter_width, row_y)
		sep.size = Vector2(maxf(300.0, _content.custom_minimum_size.x - left_gutter_width - 8.0), 1.0)
		_hours_layer.add_child(sep)

func _rebuild_if_needed(force: bool) -> void:
	var sig: String = _make_plan_signature()
	if force or sig != _last_plan_signature:
		_last_plan_signature = sig
		_rebuild_cards()

func _make_plan_signature() -> String:
	if _agent == null or not is_instance_valid(_agent):
		return ""
	if not ("today_plan" in _agent):
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

func _rebuild_cards() -> void:
	for c in _cards_layer.get_children():
		c.queue_free()

	if _agent == null or not is_instance_valid(_agent):
		return
	if not ("today_plan" in _agent):
		return
	if _agent.today_plan == null or _agent.today_plan.is_empty():
		return

	for it in _agent.today_plan:
		if typeof(it) != TYPE_DICTIONARY:
			continue

		var d: Dictionary = it
		var seg: int = int(d.get("segment", 0))
		var title: String = str(d.get("title", "")).strip_edges()
		var detail: String = str(d.get("detail", "")).strip_edges()
		var time_label: String = str(d.get("time_label", _segment_to_label(seg)))

		var start_h: float = _segment_to_hour(seg)
		var duration_h: float = 3.0 if seg < 2 else 2.5

		var y: float = (start_h - float(start_hour)) * hour_row_height
		var h: float = duration_h * hour_row_height - 6.0

		var card := PanelContainer.new()
		card.position = Vector2(left_gutter_width + card_margin_x, y + 3.0)
		card.size = Vector2(
			maxf(260.0, _content.custom_minimum_size.x - left_gutter_width - (card_margin_x * 2.0)),
			maxf(40.0, h)
		)
		_cards_layer.add_child(card)

		var pad := MarginContainer.new()
		pad.add_theme_constant_override("margin_left", int(card_inner_pad))
		pad.add_theme_constant_override("margin_right", int(card_inner_pad))
		pad.add_theme_constant_override("margin_top", int(card_inner_pad))
		pad.add_theme_constant_override("margin_bottom", int(card_inner_pad))
		card.add_child(pad)

		var content_box := VBoxContainer.new()
		content_box.add_theme_constant_override("separation", 4)
		pad.add_child(content_box)

		var top := Label.new()
		top.text = "%s  ·  %s" % [time_label, title if title != "" else "(sin título)"]
		top.add_theme_font_size_override("font_size", 14)
		content_box.add_child(top)

		if detail != "":
			var detail_lbl := Label.new()
			detail_lbl.text = detail
			detail_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			detail_lbl.modulate = Color(1, 1, 1, 0.78)
			content_box.add_child(detail_lbl)

func _update_now_line() -> void:
	if _content == null or _now_line == null:
		return

	var hour_value: float = _get_current_visual_hour()
	var y: float = (hour_value - float(start_hour)) * hour_row_height

	_now_line.position = Vector2(left_gutter_width + 2.0, y)
	_now_line.size = Vector2(maxf(280.0, _content.custom_minimum_size.x - left_gutter_width - 8.0), red_line_height)

	if auto_follow_now and _scroll != null:
		var sb: VScrollBar = _scroll.get_v_scroll_bar()
		if sb != null:
			var target: float = clampf(y - (_scroll.size.y * 0.35), 0.0, maxf(0.0, sb.max_value))
			sb.value = target

func _get_current_visual_hour() -> float:
	var clock: Node = get_tree().get_root().find_child("WorldClock", true, false)
	if clock == null:
		return 12.0

	if "current_hour" in clock:
		return clampf(float(clock.get("current_hour")), float(start_hour), float(end_hour))

	if "current_time_segment" in clock:
		var seg: int = clampi(int(clock.get("current_time_segment")), 0, 3)
		return _segment_to_hour(seg) + 0.5

	return 12.0

func _segment_to_hour(seg: int) -> float:
	match seg:
		0:
			return 8.0
		1:
			return 13.0
		2:
			return 18.0
		3:
			return 22.0
		_:
			return 8.0

func _segment_to_label(seg: int) -> String:
	match seg:
		0:
			return "Mañana"
		1:
			return "Tarde"
		2:
			return "Atardecer"
		3:
			return "Noche"
		_:
			return "Mañana"
