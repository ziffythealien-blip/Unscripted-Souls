extends Node
class_name OllamaClient

signal thought_generated(agent: Agent, text: String)
signal thought_failed(agent: Agent, error_message: String)

signal chat_reply(agent: Agent, text: String)
signal vision_reply(agent: Agent, text: String)
signal vision_failed(agent: Agent, error_message: String)

@export var model_name: String = "gemma3:4b"
@export var ollama_url: String = "http://localhost:11434/api/generate"
@export var request_timeout_sec: float = 45.0
@export var strip_reasoning_blocks: bool = true
@export var debug_print: bool = false

@export var num_predict: int = 96
@export var temperature: float = 0.55
@export var top_p: float = 0.9
@export var num_ctx: int = 2048
@export var repeat_penalty: float = 1.08
@export var stop_sequences: Array[String] = []

func generate_thought(agent: Agent, prompt: String) -> void:
	if agent == null or not is_instance_valid(agent):
		return

	var clean_prompt: String = str(prompt).strip_edges()
	if clean_prompt == "":
		thought_failed.emit(agent, "Prompt vacío.")
		return

	var full_prompt: String = _build_grounded_prompt(agent, clean_prompt)

	_request_generate(
		agent,
		full_prompt,
		[],
		func(ok: bool, text: String, err: String) -> void:
			if ok:
				thought_generated.emit(agent, text)
			else:
				thought_failed.emit(agent, err)
	)

func chat(agent: Agent, system_context: String, conversation: Array, user_text: String) -> void:
	if agent == null or not is_instance_valid(agent):
		return

	var prompt: String = _build_chat_prompt(agent, system_context, conversation, user_text)

	_request_generate(
		agent,
		prompt,
		[],
		func(ok: bool, text: String, err: String) -> void:
			if ok:
				chat_reply.emit(agent, text)
			else:
				thought_failed.emit(agent, err)
	)

func generate_vision_reply(agent: Agent, prompt: String, image_path: String) -> void:
	if agent == null or not is_instance_valid(agent):
		return

	var clean_prompt: String = str(prompt).strip_edges()
	if clean_prompt == "":
		vision_failed.emit(agent, "Prompt de visión vacío.")
		return

	if image_path.strip_edges() == "":
		vision_failed.emit(agent, "Ruta de imagen vacía.")
		return

	if not FileAccess.file_exists(image_path):
		vision_failed.emit(agent, "No existe la imagen: " + image_path)
		return

	var img_b64: String = _file_to_base64(image_path)
	if img_b64 == "":
		vision_failed.emit(agent, "No se pudo convertir imagen a base64.")
		return

	var full_prompt: String = _build_vision_prompt(agent, clean_prompt)

	_request_generate(
		agent,
		full_prompt,
		[img_b64],
		func(ok: bool, text: String, err: String) -> void:
			if ok:
				vision_reply.emit(agent, text)
			else:
				vision_failed.emit(agent, err)
	)

func _request_generate(agent: Agent, prompt: String, images: Array, cb: Callable) -> void:
	var http: HTTPRequest = HTTPRequest.new()
	add_child(http)

	if "timeout" in http:
		http.timeout = request_timeout_sec

	http.request_completed.connect(
		func(result: int, response_code: int, _headers: PackedStringArray, body_bytes: PackedByteArray) -> void:
			var parsed: Dictionary = _handle_response_body(body_bytes, result, response_code)

			if is_instance_valid(http):
				http.queue_free()

			if bool(parsed.get("ok", false)):
				cb.call(true, str(parsed.get("text", "")), "")
			else:
				cb.call(false, "", str(parsed.get("error", "Error desconocido")))
	)

	var opts: Dictionary = {
		"num_predict": num_predict,
		"temperature": temperature,
		"top_p": top_p,
		"num_ctx": num_ctx,
		"repeat_penalty": repeat_penalty
	}

	if stop_sequences.size() > 0:
		opts["stop"] = stop_sequences

	var body: Dictionary = {
		"model": model_name,
		"prompt": prompt,
		"stream": false,
		"options": opts
	}

	if not images.is_empty():
		body["images"] = images

	var headers: PackedStringArray = PackedStringArray([
		"Content-Type: application/json"
	])

	var err: int = http.request(
		ollama_url,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)

	if err != OK:
		if is_instance_valid(http):
			http.queue_free()
		cb.call(false, "", "No se pudo enviar request a Ollama. err=" + str(err))

func _handle_response_body(body: PackedByteArray, result: int, response_code: int) -> Dictionary:
	if result != OK:
		return {
			"ok": false,
			"error": "Ollama request falló. result=%s code=%s" % [str(result), str(response_code)]
		}

	if response_code != 200:
		return {
			"ok": false,
			"error": "Error Ollama HTTP %d: %s" % [response_code, body.get_string_from_utf8()]
		}

	var raw: String = body.get_string_from_utf8()
	var json: Variant = JSON.parse_string(raw)

	if typeof(json) != TYPE_DICTIONARY:
		return {
			"ok": false,
			"error": "Respuesta no es JSON dict. raw=" + raw
		}

	var d: Dictionary = json as Dictionary
	if not d.has("response"):
		return {
			"ok": false,
			"error": "JSON sin campo 'response'. raw=" + raw
		}

	var text: String = str(d["response"]).strip_edges()

	if strip_reasoning_blocks:
		text = _strip_reasoning(text)

	text = _post_clean_text(text)

	if text.strip_edges() == "":
		return {
			"ok": false,
			"error": "Respuesta vacía tras limpiar reasoning."
		}

	if debug_print:
		print("Ollama limpio => ", text)

	return {
		"ok": true,
		"text": text
	}

func _build_grounded_prompt(agent: Agent, user_prompt: String) -> String:
	var agent_name: String = _safe_agent_name(agent)
	return """
Responde como si fueras una persona viviendo dentro de un pequeño pueblo.
Habla de forma breve, natural y cotidiana.
No hables como poeta.
No uses metáforas raras.
No menciones inteligencia artificial, tecnología, simulación, prompts ni modelos.
No expliques tu razonamiento.
Escribe solo 1 o 2 frases.
Haz alusión a que sientes que realmente estás viviendo ahí.
Empieza con "Soy %s."

%s
""" % [agent_name, user_prompt.strip_edges()]

func _build_chat_prompt(agent: Agent, system_context: String, conversation: Array, user_text: String) -> String:
	var agent_name: String = _safe_agent_name(agent)
	var convo_txt: String = ""

	for m in conversation:
		if typeof(m) != TYPE_DICTIONARY:
			continue

		var role: String = str(m.get("role", "user")).to_upper()
		var txt: String = str(m.get("text", "")).strip_edges()

		if txt != "":
			convo_txt += "%s: %s\n" % [role, txt]

	return """
Responde en primera persona como si fueras %s.
Habla de forma natural, cotidiana y breve.
No menciones IA, tecnología, simulación, prompts ni modelos.
Haz alusión a que realmente vives en este lugar.
Si te preguntan qué ves, responde como alguien presente en la escena.
Máximo 3 frases.

CONTEXTO:
%s

CONVERSACIÓN PREVIA:
%s

USER: %s
AGENT:
""" % [agent_name, system_context.strip_edges(), convo_txt.strip_edges(), user_text.strip_edges()]

func _build_vision_prompt(agent: Agent, user_prompt: String) -> String:
	var agent_name: String = _safe_agent_name(agent)
	return """
Responde en primera persona como si fueras %s.
Describe solo lo que ves a tu alrededor en este momento.
Habla de forma breve, natural y cotidiana.
No menciones análisis de imagen, cámaras, capturas, screenshots, visión artificial, IA, tecnología ni modelos.
Haz alusión a que realmente estás ahí.
Empieza con "Soy %s."
Máximo 3 frases.

%s
""" % [agent_name, agent_name, user_prompt.strip_edges()]

func _strip_reasoning(text: String) -> String:
	var s: String = text.strip_edges()

	# elimina bloques completos tipo <think>...</think>
	while true:
		var open_idx: int = s.find("<think>")
		var close_idx: int = s.find("</think>")

		if open_idx == -1 or close_idx == -1 or close_idx <= open_idx:
			break

		var before: String = s.substr(0, open_idx)
		var after: String = s.substr(close_idx + "</think>".length(), s.length())
		s = (before + "\n" + after).strip_edges()

	# marcadores típicos
	var markers: Array[String] = [
		"...done thinking.",
		"Done thinking.",
		"</think>",
		"Thinking..."
	]

	for m in markers:
		var idx: int = s.find(m)
		if idx != -1:
			s = s.substr(idx + m.length(), s.length()).strip_edges()

	# filtra líneas sueltas raras
	var filtered_lines: Array[String] = []
	var lines: PackedStringArray = s.split("\n", false)

	for line in lines:
		var t: String = String(line).strip_edges()
		var lower: String = t.to_lower()

		if t == "":
			continue
		if lower.begins_with("thinking"):
			continue
		if lower == "...done thinking.":
			continue
		if lower == "done thinking.":
			continue
		if lower.find("internal reasoning") != -1:
			continue

		filtered_lines.append(t)

	s = "\n".join(filtered_lines).strip_edges()

	# si vienen varios párrafos, quédate con el más útil
	var paragraphs: PackedStringArray = s.split("\n\n", false)
	if paragraphs.size() >= 2:
		var best: String = ""
		for p in paragraphs:
			var candidate: String = String(p).strip_edges()
			if candidate.length() > best.length():
				best = candidate
		if best != "":
			s = best

	return s.strip_edges()

func _post_clean_text(text: String) -> String:
	var s: String = text.strip_edges()

	# quita comillas envolventes
	if s.begins_with("\"") and s.ends_with("\"") and s.length() >= 2:
		s = s.substr(1, s.length() - 2).strip_edges()

	# compacta saltos y espacios
	s = s.replace("\r", " ")
	s = s.replace("\n", " ")
	while s.find("  ") != -1:
		s = s.replace("  ", " ")

	# limpia prefijos raros
	var bad_prefixes: Array[String] = [
		"respuesta:",
		"pensamiento:",
		"thought:",
		"output:"
	]

	var lower: String = s.to_lower()
	for pref in bad_prefixes:
		if lower.begins_with(pref):
			s = s.substr(pref.length(), s.length()).strip_edges()
			break

	# recorta por seguridad
	if s.length() > 220:
		s = s.substr(0, 220).strip_edges()
		var last_dot: int = maxi(s.rfind("."), s.rfind("!"))
		if last_dot > 40:
			s = s.substr(0, last_dot + 1).strip_edges()

	return s

func _file_to_base64(path: String) -> String:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""

	var bytes: PackedByteArray = f.get_buffer(f.get_length())
	return Marshalls.raw_to_base64(bytes)

func _safe_agent_name(agent: Agent) -> String:
	if agent != null and is_instance_valid(agent) and agent.has_method("get_agent_name"):
		return agent.get_agent_name()
	return "Agente"
