# res://core/InboxSystem.gd
extends Node
# NO class_name (evita "hides an autoload singleton")

@export var debug_print: bool = true

# ------------------------------------------------------------
# Link config (para QR)
# ------------------------------------------------------------
@export var server_port: int = 8787
@export var inbox_path: String = "/inbox"
@export var host_mode: String = "lan" # "lan" | "loopback"
@export var token_salt: String = "unscripted-souls"

# ------------------------------------------------------------
# Queue config
# ------------------------------------------------------------
@export var max_queue_per_agent: int = 50
@export var process_interval: float = 1.25

# agent_id -> Array[Dictionary]
var _queues: Dictionary = {}
# agent_id -> token string
var _tokens: Dictionary = {}

var _timer: Timer

func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = false
	_timer.wait_time = max(0.1, process_interval)
	_timer.timeout.connect(_tick)
	add_child(_timer)
	_timer.start()

	if debug_print:
		print("InboxSystem Autoload OK: ", get_path())

# ============================================================
# Public API
# ============================================================

func get_queue_size(agent: Agent) -> int:
	if agent == null or not is_instance_valid(agent) or agent.data == null:
		return 0
	var aid: String = str(agent.data.agent_id)
	var q: Array = _queues.get(aid, [])
	return q.size()

func enqueue_item(agent: Agent, item: Dictionary) -> void:
	if agent == null or not is_instance_valid(agent) or agent.data == null:
		return

	var aid: String = str(agent.data.agent_id)
	var q: Array = _queues.get(aid, [])
	q.append(item)

	while q.size() > max_queue_per_agent:
		q.pop_front()

	_queues[aid] = q
	_emit_inbox_received(agent, item)

func pop_next_item(agent: Agent) -> Dictionary:
	if agent == null or not is_instance_valid(agent) or agent.data == null:
		return {}
	var aid: String = str(agent.data.agent_id)
	var q: Array = _queues.get(aid, [])
	if q.is_empty():
		return {}
	var item: Dictionary = q.pop_front()
	_queues[aid] = q
	return item

func build_inbox_link(agent: Agent) -> String:
	if agent == null or not is_instance_valid(agent) or agent.data == null:
		return ""

	var aid: String = str(agent.data.agent_id)
	var tok: String = _get_or_make_token(aid)

	var host: String = _resolve_host()

	var path: String = inbox_path.strip_edges()
	if path == "":
		path = "/inbox"
	if not path.begins_with("/"):
		path = "/" + path

	var aid_q: String = aid.uri_encode()
	var tok_q: String = tok.uri_encode()

	return "http://%s:%d%s?aid=%s&token=%s" % [host, server_port, path, aid_q, tok_q]

func validate(aid: String, token: String) -> bool:
	if aid.strip_edges() == "" or token.strip_edges() == "":
		return false
	var expected: String = _get_or_make_token(aid)
	return token == expected

# Llamado por tu mini-server cuando llegue algo del mundo real
func receive_external(aid: String, token: String, item: Dictionary) -> bool:
	if not validate(aid, token):
		return false

	var q: Array = _queues.get(aid, [])
	q.append(item)
	while q.size() > max_queue_per_agent:
		q.pop_front()
	_queues[aid] = q

	var agent: Agent = _find_agent_by_id(aid)
	if agent != null:
		_emit_inbox_received(agent, item)
	else:
		_toast("📮 Llegó algo al buzón %s" % aid, "msg")

	return true

# ============================================================
# Internal tick (por ahora no procesa automático)
# ============================================================

func _tick() -> void:
	# (si luego quieres procesar inbox en loop, aquí va)
	return

# ============================================================
# Helpers
# ============================================================

func _get_or_make_token(aid: String) -> String:
	if _tokens.has(aid):
		return str(_tokens[aid])

	var raw: String = token_salt + "|" + aid
	var tok: String = String.num_int64(abs(raw.hash()), 16)
	_tokens[aid] = tok
	return tok

func _resolve_host() -> String:
	if host_mode == "loopback":
		return "127.0.0.1"

	var addrs: PackedStringArray = IP.get_local_addresses()
	for a in addrs:
		# más amplio y realista para LAN
		if a.begins_with("192.168.") or a.begins_with("10.") or a.begins_with("172."):
			return a

	return "127.0.0.1"

func _find_agent_by_id(aid: String) -> Agent:
	var root := get_tree().get_root()
	var ai: Node = root.find_child("AIManager", true, false)
	if ai == null:
		return null
	var arr: Array = ai.get("agents") if ai.has_method("get") else []
	for a in arr:
		if a != null and is_instance_valid(a) and (a as Agent).data != null:
			if str((a as Agent).data.agent_id) == aid:
				return a as Agent
	return null

func _emit_inbox_received(agent: Agent, _item: Dictionary) -> void:
	var who: String = "Agente"
	if agent != null and is_instance_valid(agent):
		who = agent.get_agent_name()
	_toast("📮 %s recibió algo en su buzón" % who, "msg")

# ------------------------------------------------------------
# Toast seguro (EventBus puede ser emit_toast(text) o emit_toast(text, kind)
# ------------------------------------------------------------
func _toast(text: String, kind: String = "info") -> void:
	if not Engine.has_singleton("EventBus"):
		if debug_print:
			print(text)
		return

	# Método emit_toast
	if EventBus.has_method("emit_toast"):
		var wants_two: bool = false
		var ml: Array = EventBus.get_method_list()
		for m in ml:
			if typeof(m) == TYPE_DICTIONARY and str(m.get("name","")) == "emit_toast":
				var args: Array = m.get("args", [])
				wants_two = args.size() >= 2
				break

		if wants_two:
			EventBus.call("emit_toast", text, kind)
		else:
			EventBus.call("emit_toast", text)
		return

	# Señal toast
	if EventBus.has_signal("toast"):
		var sigs: Array = EventBus.get_signal_list()
		for s in sigs:
			if typeof(s) == TYPE_DICTIONARY and str(s.get("name","")) == "toast":
				var a2: Array = s.get("args", [])
				if a2.size() >= 2:
					EventBus.emit_signal("toast", text, kind)
				else:
					EventBus.emit_signal("toast", text)
				return

	# Fallback log
	if EventBus.has_method("emit_log"):
		EventBus.call("emit_log", text)
	elif debug_print:
		print(text)
