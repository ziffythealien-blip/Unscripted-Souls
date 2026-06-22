extends Node2D
class_name LinkSpawner

@export var bidirectional: bool = true

# Pon aquí tus conexiones (Start -> End) en coordenadas globales o locales (elige una y mantén consistencia)
@export var links: Array[Dictionary] = [
	# {"a": Vector2(300, 200), "b": Vector2(420, 210)},
]

@export var use_global_positions: bool = true

func _ready() -> void:
	_build_links()

func _build_links() -> void:
	# Borra links previos creados por este spawner
	for c in get_children():
		if c is NavigationLink2D:
			c.queue_free()

	for item in links:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var a: Vector2 = item.get("a", Vector2.ZERO)
		var b: Vector2 = item.get("b", Vector2.ZERO)

		var link := NavigationLink2D.new()
		link.bidirectional = bidirectional

		# Godot 4: usa start_position / end_position (en espacio local del link)
		# Para hacerlo simple: ponemos el link en (0,0) y usamos posiciones locales=global
		add_child(link)

		if use_global_positions:
			link.global_position = Vector2.ZERO
			link.start_position = a
			link.end_position = b
		else:
			link.position = Vector2.ZERO
			link.start_position = a
			link.end_position = b
