extends CanvasLayer
class_name SimulationHUD

static func ensure_exists(tree: SceneTree) -> SimulationHUD:
	if tree == null:
		return null

	var root_scene: Node = tree.current_scene
	if root_scene == null:
		root_scene = tree.get_root()

	var existing: Node = root_scene.find_child("SimulationHUD", true, false)
	if existing is SimulationHUD:
		return existing as SimulationHUD

	var hud: SimulationHUD = null
	var hud_scene_path := "res://scripts/ui/SimulationHUD.tscn"
	if ResourceLoader.exists(hud_scene_path):
		var packed: Resource = load(hud_scene_path)
		if packed is PackedScene:
			hud = (packed as PackedScene).instantiate() as SimulationHUD

	if hud == null:
		hud = SimulationHUD.new()

	hud.name = "SimulationHUD"
	root_scene.add_child.call_deferred(hud)
	return hud

@export var dock_width: float = 420.0
@export var topbar_height: float = 42.0
@export var margin: float = 12.0
@export var dock_right_margin_px: float = 30.0
@export var refresh_agent_list_sec: float = 0.6
@export var tint_transition_sec: float = 3.0
@export var toast_lifetime_sec: float = 30.0
@export var max_toast_history: int = 80

var _root: Control
var _topbar: PanelContainer
var _lbl_top_center: Label
var _btn_menu: Button

var _dock: PanelContainer
var _dock_v: VBoxContainer

var _agents_header: HBoxContainer
var _agents_title: Label
var _btn_toggle_list: Button

var _list_section: VBoxContainer
var _search: LineEdit
var _list: ItemList

var _btn_follow: Button
var _btn_unfollow: Button

var _agent_scroll: ScrollContainer
var _agent_panel: AgentInfoPanel

var _pointer: _AgentPointer

var _toast_stack: VBoxContainer
var _toast_history: Array[String] = []
var _btn_show_history: Button
var _history_popup: PanelContainer
var _history_label: RichTextLabel

var _clock: WorldClock = null
var _time_label: String = "Mañana"
var _season: String = "Primavera"
var _weather: String = "Despejado"

var _canvas_mod: CanvasModulate = null
var _tint_tween: Tween = null

var _selected_agent: Agent = null
var _follow_agent: Agent = null
var _agent_refresh_timer: float = 0.0
var _typing_cooldown: float = 0.0

func _ready() -> void:
	layer = 90
	_build_ui()
	_wire()
	_find_clock_and_bind()
	_refresh_agents_list()

	get_viewport().size_changed.connect(_layout)
	_layout()

	set_process(true)

func _layout() -> void:
	if _root == null:
		return

	var vp: Vector2 = get_viewport().get_visible_rect().size

	if _topbar != null:
		_topbar.offset_left = margin
		_topbar.offset_top = margin
		_topbar.offset_right = -margin
		_topbar.offset_bottom = margin + topbar_height

	if _dock != null:
		_dock.anchor_left = 1
		_dock.anchor_right = 1
		_dock.anchor_top = 0
		_dock.anchor_bottom = 1

		_dock.offset_top = margin + topbar_height + 8.0
		_dock.offset_bottom = -margin

		var min_world_space: float = 260.0
		var max_dock_w: float = max(260.0, vp.x - (margin * 2.0) - min_world_space)
		var effective_w: float = clampf(dock_width, 260.0, max_dock_w)
		var effective_right_margin: float = clampf(dock_right_margin_px, margin, 60.0)

		_dock.offset_right = -effective_right_margin
		_dock.offset_left = -(effective_w + effective_right_margin)

	if _toast_stack != null:
		_toast_stack.offset_left = margin
		_toast_stack.offset_right = margin + 360
		_toast_stack.offset_bottom = -margin
		_toast_stack.offset_top = -260

	if _history_popup != null:
		_history_popup.offset_left = margin
		_history_popup.offset_right = margin + 360
		_history_popup.offset_bottom = -margin - 260
		_history_popup.offset_top = -520

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "HUDRoot"
	_root.anchor_left = 0
	_root.anchor_top = 0
	_root.anchor_right = 1
	_root.anchor_bottom = 1
	add_child(_root)

	# =====================================================
	# TOPBAR
	# =====================================================
	_topbar = PanelContainer.new()
	_topbar.name = "TopBar"
	_topbar.anchor_left = 0
	_topbar.anchor_top = 0
	_topbar.anchor_right = 1
	_topbar.anchor_bottom = 0
	_root.add_child(_topbar)

	var top_h := HBoxContainer.new()
	top_h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_h.add_theme_constant_override("separation", 10)
	_topbar.add_child(top_h)

	var sp_l := Control.new()
	sp_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_h.add_child(sp_l)

	_lbl_top_center = Label.new()
	_lbl_top_center.text = "Simulación"
	_lbl_top_center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_top_center.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_h.add_child(_lbl_top_center)

	var sp_r := Control.new()
	sp_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_h.add_child(sp_r)

	_btn_menu = Button.new()
	_btn_menu.text = "≡"
	_btn_menu.tooltip_text = "Mostrar/Ocultar panel principal"
	top_h.add_child(_btn_menu)

	# =====================================================
	# DOCK
	# =====================================================
	_dock = PanelContainer.new()
	_dock.name = "RightDock"
	_root.add_child(_dock)

	_dock_v = VBoxContainer.new()
	_dock_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dock_v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dock_v.add_theme_constant_override("separation", 8)
	_dock.add_child(_dock_v)

	# -----------------------------------------------------
	# HEADER AGENTES SIEMPRE VISIBLE
	# -----------------------------------------------------
	_agents_header = HBoxContainer.new()
	_agents_header.add_theme_constant_override("separation", 8)
	_dock_v.add_child(_agents_header)

	_agents_title = Label.new()
	_agents_title.text = "Agentes"
	_agents_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_agents_header.add_child(_agents_title)

	_btn_toggle_list = Button.new()
	_btn_toggle_list.text = "✕"
	_btn_toggle_list.tooltip_text = "Ocultar lista de agentes"
	_agents_header.add_child(_btn_toggle_list)

	# -----------------------------------------------------
	# SECCION COLAPSABLE DE LISTA
	# -----------------------------------------------------
	_list_section = VBoxContainer.new()
	_list_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_section.add_theme_constant_override("separation", 4)
	_dock_v.add_child(_list_section)

	_search = LineEdit.new()
	_search.placeholder_text = "Buscar agente..."
	_list_section.add_child(_search)

	_list = ItemList.new()
	_list.allow_reselect = true
	_list.select_mode = ItemList.SELECT_SINGLE
	_list.custom_minimum_size = Vector2(0, 160)
	_list.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_list_section.add_child(_list)

	# -----------------------------------------------------
	# BOTONES
	# -----------------------------------------------------
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	_dock_v.add_child(hb)

	_btn_follow = Button.new()
	_btn_follow.text = "Seguir"
	hb.add_child(_btn_follow)

	_btn_unfollow = Button.new()
	_btn_unfollow.text = "Dejar de seguir"
	hb.add_child(_btn_unfollow)

	# -----------------------------------------------------
	# PANEL AGENTE
	# -----------------------------------------------------
	_agent_scroll = ScrollContainer.new()
	_agent_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_agent_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_agent_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_agent_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_dock_v.add_child(_agent_scroll)

	_agent_panel = AgentInfoPanel.new()
	_agent_panel.name = "AgentInfoPanel"
	_agent_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_agent_scroll.add_child(_agent_panel)

	# -----------------------------------------------------
	# POINTER
	# -----------------------------------------------------
	_pointer = _AgentPointer.new()
	_pointer.visible = false
	_root.add_child(_pointer)

	# -----------------------------------------------------
	# TOASTS / HISTORIAL
	# -----------------------------------------------------
	_toast_stack = VBoxContainer.new()
	_toast_stack.anchor_left = 0
	_toast_stack.anchor_right = 0
	_toast_stack.anchor_top = 1
	_toast_stack.anchor_bottom = 1
	_toast_stack.add_theme_constant_override("separation", 6)
	_root.add_child(_toast_stack)

	var toast_header := HBoxContainer.new()
	_toast_stack.add_child(toast_header)

	_btn_show_history = Button.new()
	_btn_show_history.text = "Historial"
	toast_header.add_child(_btn_show_history)

	_history_popup = PanelContainer.new()
	_history_popup.visible = false
	_history_popup.anchor_left = 0
	_history_popup.anchor_right = 0
	_history_popup.anchor_top = 1
	_history_popup.anchor_bottom = 1
	_root.add_child(_history_popup)

	_history_label = RichTextLabel.new()
	_history_label.bbcode_enabled = true
	_history_label.scroll_active = true
	_history_label.custom_minimum_size = Vector2(340, 240)
	_history_popup.add_child(_history_label)

	_layout()
	_set_agent_list_visible(true)

func _wire() -> void:
	_btn_menu.pressed.connect(func() -> void:
		_dock.visible = not _dock.visible
	)

	_btn_toggle_list.pressed.connect(func() -> void:
		_set_agent_list_visible(not _list_section.visible)
	)

	_search.text_changed.connect(func(_t: String) -> void:
		_typing_cooldown = 0.35
		_refresh_agents_list()
	)

	_search.text_submitted.connect(func(_t: String) -> void:
		_refresh_agents_list()
		if _list.item_count > 0:
			_list.select(0)
			_on_list_selected(0)
	)

	_list.item_selected.connect(func(idx: int) -> void:
		_on_list_selected(idx)
	)

	_btn_follow.pressed.connect(func() -> void:
		if _selected_agent != null and is_instance_valid(_selected_agent):
			_follow_agent = _selected_agent
			if Engine.has_singleton("EventBus"):
				EventBus.emit_follow(_follow_agent)
			_pointer.set_agent(_follow_agent)
	)

	_btn_unfollow.pressed.connect(func() -> void:
		_follow_agent = null
		if Engine.has_singleton("EventBus"):
			EventBus.emit_unfollow()
		_pointer.clear_agent()
	)

	_btn_show_history.pressed.connect(func() -> void:
		_history_popup.visible = not _history_popup.visible
		_refresh_history_text()
	)

	if Engine.has_singleton("EventBus"):
		if not EventBus.agent_selected.is_connected(_on_agent_selected):
			EventBus.agent_selected.connect(_on_agent_selected)
		if not EventBus.agent_clicked.is_connected(_on_agent_selected):
			EventBus.agent_clicked.connect(_on_agent_selected)

		if EventBus.has_signal("toast") and not EventBus.toast.is_connected(_on_toast):
			EventBus.toast.connect(_on_toast)

		if EventBus.has_signal("log_event") and not EventBus.log_event.is_connected(_on_log_event):
			EventBus.log_event.connect(_on_log_event)

func _process(delta: float) -> void:
	if _typing_cooldown > 0.0:
		_typing_cooldown = max(0.0, _typing_cooldown - delta)
	else:
		_agent_refresh_timer += delta
		if _agent_refresh_timer >= refresh_agent_list_sec:
			_agent_refresh_timer = 0.0
			if _list_section.visible:
				_refresh_agents_list()

	if _pointer != null:
		_pointer.update_pointer()

	_update_topbar_text()

func _set_agent_list_visible(visible_state: bool) -> void:
	if _list_section == null or _btn_toggle_list == null:
		return

	_list_section.visible = visible_state

	if visible_state:
		_btn_toggle_list.text = "✕"
		_btn_toggle_list.tooltip_text = "Ocultar lista de agentes"
	else:
		_btn_toggle_list.text = "☰"
		_btn_toggle_list.tooltip_text = "Mostrar lista de agentes"

func _find_clock_and_bind() -> void:
	var root_scene: Node = get_tree().current_scene
	if root_scene == null:
		root_scene = get_tree().get_root()

	var c: Node = root_scene.find_child("WorldClock", true, false)
	if c is WorldClock:
		_clock = c as WorldClock
	else:
		c = get_tree().get_root().find_child("WorldClock", true, false)
		if c is WorldClock:
			_clock = c as WorldClock

	if _clock == null:
		return

	if not _clock.day_started.is_connected(_on_day_started):
		_clock.day_started.connect(_on_day_started)
	if not _clock.time_of_day_changed.is_connected(_on_time_changed):
		_clock.time_of_day_changed.connect(_on_time_changed)
	if not _clock.weather_changed.is_connected(_on_weather_changed):
		_clock.weather_changed.connect(_on_weather_changed)

	_season = _clock.get_current_season()
	_time_label = _clock.get_time_label()
	_weather = _clock.current_weather

	var vfx := WeatherVFX.ensure_exists(get_tree())
	if vfx != null:
		vfx.bind_clock(_clock)

	_apply_time_tint(_time_label)

func _on_day_started(_d: int, season: String) -> void:
	_season = season

func _on_time_changed(time_period: String) -> void:
	_time_label = time_period
	_apply_time_tint(_time_label)

func _on_weather_changed(weather: String) -> void:
	_weather = weather

func _ensure_canvas_modulate() -> void:
	if _canvas_mod != null and is_instance_valid(_canvas_mod):
		return

	var root_scene: Node = get_tree().current_scene
	if root_scene == null:
		root_scene = get_tree().get_root()

	var existing: Node = root_scene.find_child("TimeTint", true, false)
	if existing is CanvasModulate:
		_canvas_mod = existing as CanvasModulate
		return

	var cm := CanvasModulate.new()
	cm.name = "TimeTint"
	root_scene.add_child.call_deferred(cm)
	_canvas_mod = cm

func _target_tint_for(label: String) -> Color:
	if label == "Mañana":
		return Color(1, 1, 1, 1)
	if label == "Tarde":
		return Color(1.05, 0.97, 0.90, 1)
	if label == "Atardecer":
		return Color(1.08, 0.86, 0.78, 1)
	return Color(0.62, 0.72, 0.95, 1)

func _apply_time_tint(label: String) -> void:
	_ensure_canvas_modulate()
	if _canvas_mod == null:
		return

	var target: Color = _target_tint_for(label)

	if _tint_tween != null and is_instance_valid(_tint_tween):
		_tint_tween.kill()

	_tint_tween = create_tween()
	_tint_tween.tween_property(_canvas_mod, "color", target, max(0.1, tint_transition_sec))

func _update_topbar_text() -> void:
	var real_dt := Time.get_datetime_dict_from_system()
	var real_time: String = "%04d-%02d-%02d %02d:%02d:%02d" % [
		int(real_dt.year), int(real_dt.month), int(real_dt.day),
		int(real_dt.hour), int(real_dt.minute), int(real_dt.second)
	]

	var sim_season: String = _season
	var sim_period: String = _time_label
	var sim_weather: String = _weather

	if _clock != null and is_instance_valid(_clock):
		sim_season = _clock.get_current_season()
		sim_period = _clock.get_time_label()
		sim_weather = _clock.current_weather

	_lbl_top_center.text = "🕒 %s   |   🌿 %s • %s • ☁ %s" % [
		real_time,
		sim_season,
		sim_period,
		sim_weather
	]

func _on_toast(text: String) -> void:
	_push_toast(text)

func _on_log_event(text: String) -> void:
	_add_history(text)

func _push_toast(text: String) -> void:
	_add_history(text)

	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.modulate = Color(1, 1, 1, 1)
	_toast_stack.add_child(lbl)

	var tw := create_tween()
	tw.tween_interval(toast_lifetime_sec)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.7)
	tw.tween_callback(func() -> void:
		if is_instance_valid(lbl):
			lbl.queue_free()
	)

func _add_history(text: String) -> void:
	_toast_history.append(text)
	if _toast_history.size() > max_toast_history:
		_toast_history.pop_front()

func _refresh_history_text() -> void:
	var lines: Array[String] = []
	for t in _toast_history:
		lines.append("• " + str(t))
	_history_label.text = "\n".join(lines)

func _refresh_agents_list() -> void:
	var ai: AIManager = _find_ai_manager()
	if ai == null:
		return

	var filter: String = _search.text.strip_edges().to_lower()
	var prev_selected_name: String = ""
	if _list.get_selected_items().size() > 0:
		prev_selected_name = _list.get_item_text(_list.get_selected_items()[0])

	_list.clear()

	for a in ai.agents:
		if a == null or not is_instance_valid(a):
			continue
		var nm: String = a.get_agent_name()
		if filter != "" and nm.to_lower().find(filter) == -1:
			continue
		_list.add_item(nm)

	if prev_selected_name != "":
		for i in range(_list.item_count):
			if _list.get_item_text(i) == prev_selected_name:
				_list.select(i)
				break

func _on_list_selected(idx: int) -> void:
	if idx < 0 or idx >= _list.item_count:
		return

	var name_sel: String = _list.get_item_text(idx)
	var ai: AIManager = _find_ai_manager()
	if ai == null:
		return

	for a in ai.agents:
		if a != null and is_instance_valid(a) and a.get_agent_name() == name_sel:
			_on_agent_selected(a)
			return

func _on_agent_selected(agent: Agent) -> void:
	_selected_agent = agent

	if _agent_panel != null:
		_agent_panel.set_agent(agent)

	if _pointer != null:
		_pointer.set_agent(agent)

	if not _dock.visible:
		_dock.visible = true

func _find_ai_manager() -> AIManager:
	var root_scene: Node = get_tree().current_scene
	if root_scene == null:
		root_scene = get_tree().get_root()

	var n: Node = root_scene.find_child("AIManager", true, false)
	if n is AIManager:
		return n as AIManager

	n = get_tree().get_root().find_child("AIManager", true, false)
	if n is AIManager:
		return n as AIManager

	return null

class _AgentPointer extends Control:
	var agent: Agent = null
	var lbl: Label

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(160, 40)

		lbl = Label.new()
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		add_child(lbl)

	func set_agent(a: Agent) -> void:
		agent = a
		if agent != null and is_instance_valid(agent):
			lbl.text = "⬇ " + agent.get_agent_name()
			visible = true
		else:
			clear_agent()

	func clear_agent() -> void:
		agent = null
		lbl.text = ""
		visible = false

	func update_pointer() -> void:
		if agent == null or not is_instance_valid(agent):
			clear_agent()
			return

		var ct: Transform2D = get_viewport().get_canvas_transform()
		var screen_pos: Vector2 = ct * agent.global_position
		position = screen_pos + Vector2(-custom_minimum_size.x * 0.5, -56)
		queue_redraw()

	func _draw() -> void:
		if not visible:
			return

		var w: float = size.x
		var h: float = size.y
		var p1 := Vector2(w * 0.5, h)
		var p2 := Vector2(w * 0.5 - 8, h - 10)
		var p3 := Vector2(w * 0.5 + 8, h - 10)
		draw_polygon(
			PackedVector2Array([p1, p2, p3]),
			PackedColorArray([Color(1, 1, 1, 0.95)])
		)
