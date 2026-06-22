extends Node
class_name AIManager

var agents: Array[Agent] = []

var emotion_system: EmotionSystem
var existential_system: ExistentialSystem
var planner: Planner
var save_system: SaveSystem

var agent_scene: PackedScene
var ollama_client: OllamaClient

@export var existential_chance: float = 0.35
@export var debug_mode: bool = true

@export var female_names: Array[String] = ["Elena","Liliana","Camila","Valeria","Sofía","Isabella","Lucía","Renata"]
@export var male_names: Array[String] = ["Victor","Daniel","Mateo","Samuel","Andrés","Gabriel","Marcos","Tomás"]

@export_file("*.png") var female_sheet_path: String = ""
@export_file("*.png") var male_sheet_path: String = ""

@export var female_name_to_sheet: Dictionary = {}
@export var male_name_to_sheet: Dictionary = {}

var _female_sheet: Texture2D = null
var _male_sheet: Texture2D = null

@export var female_rows: Array[int] = [0,1,2,3,4,5,6,7]
@export var male_rows: Array[int] = [0,1,2,3,4,5,6,7]

@export var frame_size: Vector2i = Vector2i(16, 16)
@export var frames_per_dir: int = 3
@export var dir_order: Array[String] = ["down", "left", "right", "up"]
@export var fps_walk: float = 8.0

var _used_female_indices: Dictionary = {}
var _used_male_indices: Dictionary = {}

var _last_processed_day: int = -999999
var _last_processed_season: String = ""

# =====================================================
# OLLAMA: COLA + WATCHDOG + COOLDOWN
# =====================================================

@export var ollama_timeout_sec: float = 45.0
@export var max_concurrent_thoughts: int = 1
@export var min_days_between_thoughts: int = 2

# Bajados para reducir spam / consumo
@export var per_segment_thought_chance: float = 0.02
@export var talk_to_user_chance_per_day: float = 0.02

# Control de ruido visual
@export var toast_on_reflection_start: bool = false
@export var toast_on_reflection_success: bool = true
@export var toast_on_reflection_fail: bool = true

var _thought_queue: Array[Agent] = []
var _active_thoughts: int = 0
var _pending_thought_since: Dictionary = {}      # Agent -> unix
var _pending_season: Dictionary = {}             # Agent -> season string
var _last_thought_day_by_agent: Dictionary = {}  # Agent -> int day_number
var _last_segment_thought_at: Dictionary = {}    # Agent -> unix

func _ready() -> void:
	randomize()
	if debug_mode:
		print("AIManager listo.")

	_initialize_systems()
	agent_scene = preload("res://scenes/Agent.tscn")

	_female_sheet = _load_texture_or_null(female_sheet_path)
	_male_sheet = _load_texture_or_null(male_sheet_path)

	call_deferred("_setup_ollama")
	call_deferred("_connect_world_clock")

func _initialize_systems() -> void:
	emotion_system = EmotionSystem.new()
	existential_system = ExistentialSystem.new()
	planner = Planner.new()
	save_system = SaveSystem.new()

	add_child(emotion_system)
	add_child(existential_system)
	add_child(planner)
	add_child(save_system)

func _load_texture_or_null(path: String) -> Texture2D:
	if path == null or path.strip_edges() == "":
		return null
	if not ResourceLoader.exists(path):
		return null
	var res: Resource = load(path)
	if res is Texture2D:
		return res as Texture2D
	return null

# =====================================================
# WorldClock
# =====================================================

func _connect_world_clock() -> void:
	var world_clock: Node = get_tree().get_root().find_child("WorldClock", true, false)
	if world_clock == null:
		await get_tree().process_frame
		_connect_world_clock()
		return

	if world_clock.has_signal("day_started") and not world_clock.day_started.is_connected(simulate_day):
		world_clock.day_started.connect(simulate_day)

	if world_clock.has_signal("time_of_day_changed") and not world_clock.time_of_day_changed.is_connected(_on_time_segment_changed):
		world_clock.time_of_day_changed.connect(_on_time_segment_changed)

	if debug_mode:
		print("WorldClock detectado.")

	call_deferred("_sync_initial_world_state", world_clock)

func _find_navigation_region() -> NavigationRegion2D:
	var root_node: Node = get_tree().current_scene
	if root_node == null:
		root_node = get_tree().get_root()

	var found: Node = root_node.find_child("NavigationRegion2D", true, false)
	if found is NavigationRegion2D:
		return found as NavigationRegion2D

	return _find_navigation_region_recursive(root_node)

func _find_navigation_region_recursive(node: Node) -> NavigationRegion2D:
	if node is NavigationRegion2D:
		return node as NavigationRegion2D

	for child in node.get_children():
		var result: NavigationRegion2D = _find_navigation_region_recursive(child)
		if result != null:
			return result

	return null

func _get_navigation_map_rid() -> RID:
	var region: NavigationRegion2D = _find_navigation_region()
	if region == null:
		return RID()

	return region.get_world_2d().navigation_map

func _sync_initial_world_state(world_clock: Node) -> void:
	if world_clock == null:
		return

	var tries: int = 0
	while tries < 120:
		var map_rid: RID = _get_navigation_map_rid()
		if map_rid.is_valid() and NavigationServer2D.map_get_iteration_id(map_rid) > 0:
			break
		tries += 1
		await get_tree().process_frame

	var day_number: int = 0
	var season: String = "Primavera"

	if "current_day" in world_clock:
		day_number = int(world_clock.get("current_day"))

	if world_clock.has_method("get_current_season"):
		season = str(world_clock.call("get_current_season"))
	elif "current_season" in world_clock:
		season = str(world_clock.get("current_season"))

	simulate_day(day_number, season)
	_on_time_segment_changed("", -1)

func _on_time_segment_changed(_label: String, _seg: int = -1) -> void:
	_process_thought_queue()
	_watchdog_thoughts()

	_clean_agent_list()
	if agents.is_empty():
		return

	for a in agents:
		if a == null or not is_instance_valid(a):
			continue
		if a.awaiting_thought:
			continue

		var last_t: int = int(_last_segment_thought_at.get(a, 0))
		if (Time.get_unix_time_from_system() - last_t) < 90:
			continue

		if randf() < per_segment_thought_chance:
			_last_segment_thought_at[a] = Time.get_unix_time_from_system()
			_queue_existential_thought_if_needed(a, _last_processed_season, _last_processed_day)

	_process_thought_queue()

# =====================================================
# Ollama
# =====================================================

func _setup_ollama() -> void:
	ollama_client = OllamaClient.new()
	add_child(ollama_client)

	if not ollama_client.thought_generated.is_connected(_on_thought_generated):
		ollama_client.thought_generated.connect(_on_thought_generated)

	if ollama_client.has_signal("thought_failed"):
		if not ollama_client.thought_failed.is_connected(_on_thought_failed):
			ollama_client.thought_failed.connect(_on_thought_failed)

	if debug_mode:
		print("Ollama sincronizado.")

# =====================================================
# SPAWN
# =====================================================

func spawn_initial_agents(amount: int) -> Array[Agent]:
	var spawned: Array[Agent] = []
	var container: Node = get_tree().get_root().find_child("Agents", true, false)
	if container == null:
		push_error("Nodo 'Agents' no encontrado.")
		return []

	_used_female_indices.clear()
	_used_male_indices.clear()

	_thought_queue.clear()
	_pending_season.clear()
	_pending_thought_since.clear()
	_active_thoughts = 0
	_last_thought_day_by_agent.clear()
	_last_segment_thought_at.clear()

	var used_names: Dictionary = {}
	for ex in agents:
		if is_instance_valid(ex):
			used_names[String(ex.name)] = true

	for i in range(amount):
		var a: Agent = agent_scene.instantiate() as Agent
		var gender: String = "male" if randf() > 0.5 else "female"

		var d: AgentData = AgentData.new()
		d.gender = gender
		d.agent_name = _generate_unique_name_by_gender(gender, used_names)
		used_names[d.agent_name] = true

		d.personality = {
			"introspection": randf_range(0.0, 1.0),
			"sociability": randf_range(0.0, 1.0),
			"stability": randf_range(0.3, 1.0)
		}

		a.initialize(d)
		a.name = d.agent_name
		a.position = Vector2(randf_range(100, 900), randf_range(100, 500))
		container.add_child(a)

		var sheet: Texture2D = _pick_sheet_for_agent(d.agent_name, gender)
		var char_index: int = _pick_unique_character_index(gender)

		if sheet != null and a.has_method("apply_spritesheet_character"):
			a.apply_spritesheet_character(sheet, char_index, frame_size, frames_per_dir, dir_order, fps_walk)

		_last_thought_day_by_agent[a] = -999999
		spawned.append(a)

	agents = spawned
	_initialize_social_network()

	_log("👥 Agentes creados: %d" % agents.size())
	return spawned

func _pick_sheet_for_agent(agent_name: String, gender: String) -> Texture2D:
	if gender == "female":
		var p: String = str(female_name_to_sheet.get(agent_name, ""))
		var t: Texture2D = _load_texture_or_null(p)
		if t != null:
			return t
		return _female_sheet
	else:
		var p2: String = str(male_name_to_sheet.get(agent_name, ""))
		var t2: Texture2D = _load_texture_or_null(p2)
		if t2 != null:
			return t2
		return _male_sheet

func _pick_unique_character_index(gender: String) -> int:
	var pool: Array[int] = male_rows if gender == "male" else female_rows
	if pool.is_empty():
		return 0

	var used: Dictionary = _used_male_indices if gender == "male" else _used_female_indices
	var available: Array[int] = []
	for idx in pool:
		if not used.has(idx):
			available.append(idx)

	if available.is_empty():
		used.clear()
		available = pool.duplicate()

	var pick: int = available[randi() % available.size()]
	used[pick] = true
	return pick

func _generate_unique_name_by_gender(gender: String, used_names: Dictionary) -> String:
	var pool: Array[String] = female_names if gender == "female" else male_names
	var available: Array[String] = []
	for n in pool:
		if not used_names.has(n):
			available.append(n)

	if available.is_empty():
		return "Persona_" + str(randi() % 9999)

	return available[randi() % available.size()]

func _initialize_social_network() -> void:
	for agent in agents:
		for other in agents:
			if agent == other:
				continue
			if agent.has_method("set_affinity_with"):
				agent.set_affinity_with(other, randf_range(-0.3, 0.8))

# =====================================================
# CICLO DIARIO
# =====================================================

func simulate_day(day_number: int, season: String) -> void:
	if day_number == _last_processed_day and season == _last_processed_season:
		return
	_last_processed_day = day_number
	_last_processed_season = season

	_clean_agent_list()
	if agents.is_empty():
		return

	_maybe_ping_user(day_number)

	for agent in agents:
		emotion_system.daily_update(agent)
		existential_system.update(agent, day_number)

		agent.evaluate_needs()
		planner.generate_schedule(agent, agents)
		agent.execute_next_task(self)

		_queue_existential_thought_if_needed(agent, season, day_number)

	_process_thought_queue()
	_watchdog_thoughts()

func _maybe_ping_user(day_number: int) -> void:
	if randf() >= talk_to_user_chance_per_day:
		return
	if agents.is_empty():
		return
	var a: Agent = agents[randi() % agents.size()]
	if a == null or not is_instance_valid(a):
		return

	_toast("✨ %s quiere hablar contigo." % a.get_agent_name(), "msg")
	_log("✨ %s quiere hablar con el usuario (día %d)." % [a.get_agent_name(), day_number])

# =====================================================
# OLLAMA QUEUE
# =====================================================

func _queue_existential_thought_if_needed(agent: Agent, season: String, day_number: int) -> void:
	if agent == null or not is_instance_valid(agent):
		return
	if ollama_client == null:
		return
	if agent.awaiting_thought:
		return
	if _thought_queue.has(agent):
		return

	var last_day: int = int(_last_thought_day_by_agent.get(agent, -999999))
	if min_days_between_thoughts > 0 and (day_number - last_day) < min_days_between_thoughts:
		return

	var introspection: float = 0.5
	if agent.data != null:
		introspection = float(agent.data.personality.get("introspection", 0.5))

	var seasonal_modifier: float = 0.0
	if season == "Invierno":
		seasonal_modifier = 0.15
	elif season == "Primavera":
		seasonal_modifier = -0.1

	var chance: float = clampf(existential_chance + (introspection * 0.4) + seasonal_modifier, 0.0, 1.0)
	if randf() < chance:
		_thought_queue.append(agent)
		_pending_season[agent] = season

func _process_thought_queue() -> void:
	if ollama_client == null:
		return

	while _active_thoughts < max_concurrent_thoughts and not _thought_queue.is_empty():
		var agent: Agent = _thought_queue.pop_front()
		if agent == null or not is_instance_valid(agent):
			continue
		if agent.awaiting_thought:
			continue

		var season: String = str(_pending_season.get(agent, ""))
		_pending_season.erase(agent)
		request_existential_thought(agent, season)

func request_existential_thought(agent: Agent, season: String = "") -> void:
	if ollama_client == null or agent == null or not is_instance_valid(agent):
		return

	agent.awaiting_thought = true
	_active_thoughts += 1
	_pending_thought_since[agent] = Time.get_unix_time_from_system()

	if toast_on_reflection_start:
		_toast("💭 %s está reflexionando…" % agent.get_agent_name(), "info")

	var intro: float = 0.5
	if agent.data != null:
		intro = float(agent.data.personality.get("introspection", 0.5))

	var prompt: String = """
Eres alguien que vive de verdad en un pequeño pueblo tranquilo.
Hoy es %s.
Piensa de forma breve, natural y cotidiana.
No hables de tecnología, IA, simulación ni nada parecido.
Escribe solo 1 o 2 frases.
Introspección: %.2f
""" % [season, intro]

	ollama_client.generate_thought(agent, prompt)

func _on_thought_generated(agent: Agent, text: String) -> void:
	if not is_instance_valid(agent):
		return

	_pending_thought_since.erase(agent)
	_last_thought_day_by_agent[agent] = _last_processed_day

	if agent.awaiting_thought:
		agent.awaiting_thought = false

	_active_thoughts = max(0, _active_thoughts - 1)

	var clean: String = text.strip_edges()
	agent.long_memory.append({
		"type": "thought",
		"text": clean,
		"timestamp": Time.get_unix_time_from_system()
	})

	if agent.long_memory.size() > 250:
		agent.long_memory.pop_front()

	if Engine.has_singleton("EventBus"):
		EventBus.emit_thought_generated(agent, clean)

	if toast_on_reflection_success:
		_toast("🧠 %s pensó algo nuevo." % agent.get_agent_name(), "ok")

	_process_thought_queue()

func _on_thought_failed(agent: Agent, error_message: String) -> void:
	if not is_instance_valid(agent):
		return

	_pending_thought_since.erase(agent)
	_last_thought_day_by_agent[agent] = _last_processed_day

	if agent.awaiting_thought:
		agent.awaiting_thought = false

	_active_thoughts = max(0, _active_thoughts - 1)

	_log("❌ Ollama fail para %s: %s" % [agent.get_agent_name(), error_message])

	if toast_on_reflection_fail:
		_toast("⚠ Ollama falló para %s" % agent.get_agent_name(), "warn")

	_process_thought_queue()

func _watchdog_thoughts() -> void:
	for a in agents:
		if a != null and is_instance_valid(a) and a.awaiting_thought:
			var t0: int = int(_pending_thought_since.get(a, 0))
			if t0 > 0 and (Time.get_unix_time_from_system() - t0) > int(ollama_timeout_sec):
				a.awaiting_thought = false
				_pending_thought_since.erase(a)
				_active_thoughts = max(0, _active_thoughts - 1)
				_last_thought_day_by_agent[a] = _last_processed_day

				_log("⚠ Ollama timeout para " + a.get_agent_name())

				if toast_on_reflection_fail:
					_toast("⚠ Timeout de Ollama: " + a.get_agent_name(), "warn")

				_process_thought_queue()

# =====================================================
# UTIL
# =====================================================

func get_random_agent() -> Agent:
	if agents.is_empty():
		return null
	return agents[randi() % agents.size()]

func _clean_agent_list() -> void:
	var cleaned: Array[Agent] = []
	for a in agents:
		if is_instance_valid(a):
			cleaned.append(a)
	agents = cleaned

# =====================================================
# SAFE EventBus helpers
# =====================================================

func _toast(text: String, kind: String = "info") -> void:
	if not Engine.has_singleton("EventBus"):
		if debug_mode:
			print("[TOAST %s] %s" % [kind, text])
		return

	if EventBus.has_method("emit_toast"):
		var wants_two: bool = false
		var ml: Array = EventBus.get_method_list()
		for m in ml:
			if m is Dictionary and str(m.get("name", "")) == "emit_toast":
				var args: Array = m.get("args", [])
				wants_two = args.size() >= 2
				break

		if wants_two:
			EventBus.call("emit_toast", text, kind)
		else:
			EventBus.call("emit_toast", text)
		return

	if EventBus.has_signal("toast2"):
		EventBus.emit_signal("toast2", text, kind)
		return

	if EventBus.has_signal("toast"):
		EventBus.emit_signal("toast", text)
		return

	if debug_mode:
		print("[TOAST %s] %s" % [kind, text])

func _log(text: String) -> void:
	if Engine.has_singleton("EventBus") and EventBus.has_method("emit_log"):
		EventBus.call("emit_log", text)
	elif Engine.has_singleton("EventBus") and EventBus.has_signal("log_event"):
		EventBus.emit_signal("log_event", text)
	elif debug_mode:
		print(text)
