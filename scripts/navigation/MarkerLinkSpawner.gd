extends Node2D
class_name MarkerLinkSpawner

@export var markers_root_path: NodePath
@export var links_parent_path: NodePath
@export var bidirectional: bool = true
@export var use_current_scene_root_for_globals: bool = false

func _ready() -> void:
	call_deferred("_build_links")

func _build_links() -> void:
	var markers_root: Node = get_node_or_null(markers_root_path)
	if markers_root == null:
		push_warning("MarkerLinkSpawner: No encontré markers_root_path")
		return

	var links_parent: Node = get_node_or_null(links_parent_path)
	if links_parent == null:
		push_warning("MarkerLinkSpawner: No encontré links_parent_path")
		return

	for c in links_parent.get_children():
		if c is NavigationLink2D:
			c.queue_free()

	var groups: Dictionary = {}

	for child in markers_root.get_children():
		if not (child is Marker2D):
			continue

		var m: Marker2D = child as Marker2D
		var n: String = m.name

		if n.ends_with("_A"):
			var prefix_a: String = n.substr(0, n.length() - 2)
			if not groups.has(prefix_a):
				groups[prefix_a] = {}
			groups[prefix_a]["A"] = m

		elif n.ends_with("_B"):
			var prefix_b: String = n.substr(0, n.length() - 2)
			if not groups.has(prefix_b):
				groups[prefix_b] = {}
			groups[prefix_b]["B"] = m

	for prefix in groups.keys():
		var g: Dictionary = groups[prefix]

		if not (g.has("A") and g.has("B")):
			push_warning("MarkerLinkSpawner: Falta A o B en grupo: " + str(prefix))
			continue

		var marker_a: Marker2D = g["A"] as Marker2D
		var marker_b: Marker2D = g["B"] as Marker2D

		# ✅ más robusto que global_position
		var a_global: Vector2 = marker_a.to_global(Vector2.ZERO)
		var b_global: Vector2 = marker_b.to_global(Vector2.ZERO)

		var link := NavigationLink2D.new()
		link.name = str(prefix) + "_Link"
		link.bidirectional = bidirectional

		links_parent.add_child(link)

		# dejamos el link en origen global para que start/end usen coords globales limpias
		link.global_position = Vector2.ZERO
		link.start_position = a_global
		link.end_position = b_global

		print("Link creado: ", link.name, "  A=", a_global, "  B=", b_global)
