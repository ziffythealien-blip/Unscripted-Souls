extends Node
class_name LightController

@export var home_assistant_url: String = "http://127.0.0.1:8123"
@export var access_token: String = ""
@export var debug_print: bool = true

func turn_on_light(entity_id: String) -> void:
	_call_service("light", "turn_on", entity_id)

func turn_off_light(entity_id: String) -> void:
	_call_service("light", "turn_off", entity_id)

func toggle_light(entity_id: String) -> void:
	_call_service("light", "toggle", entity_id)

func _call_service(domain: String, service: String, entity_id: String) -> void:
	if entity_id.strip_edges() == "":
		if debug_print:
			print("LightController: entity_id vacío.")
		return

	if home_assistant_url.strip_edges() == "":
		if debug_print:
			print("LightController: home_assistant_url vacío.")
		return

	if access_token.strip_edges() == "":
		if debug_print:
			print("LightController: access_token vacío.")
		return

	var http := HTTPRequest.new()
	add_child(http)

	http.request_completed.connect(
		func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
			if debug_print:
				print("LightController -> ", domain, ".", service, " ", entity_id, " | result=", result, " code=", response_code)
				if body.size() > 0:
					print(body.get_string_from_utf8())
			if is_instance_valid(http):
				http.queue_free()
	)

	var url: String = "%s/api/services/%s/%s" % [
		home_assistant_url.rstrip("/"),
		domain,
		service
	]

	var headers := PackedStringArray([
		"Authorization: Bearer " + access_token,
		"Content-Type: application/json"
	])

	var payload: Dictionary = {
		"entity_id": entity_id
	}

	var err: int = http.request(
		url,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)

	if err != OK:
		if debug_print:
			print("LightController: error enviando request -> ", err)
		if is_instance_valid(http):
			http.queue_free()
