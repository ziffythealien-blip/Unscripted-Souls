extends Node2D
class_name Agent

# =====================================================
# IDENTIDAD
# =====================================================

var data: AgentData = null
@onready var sprite: AnimatedSprite2D = $Sprite2D
@onready var nav: NavigationAgent2D = get_node_or_null("NavigationAgent2D")
@onready var col_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")

# =====================================================
# MOVIMIENTO
# =====================================================

@export var speed: float = 60.0
@export var interaction_distance: float = 18.0

@export var destination_jitter: float = 10.0
@export var social_offset_radius: float = 14.0

@export var unstuck_enabled: bool = true
@export var unstuck_push: float = 22.0

@export var clamp_to_bounds: bool = true
@export var world_min: Vector2 = Vector2(0, 0)
@export var world_max: Vector2 = Vector2(2200, 1200)

@export var debug_nav: bool = false

# Separación social
@export var social_ring_radius: float = 30.0
@export var social_min_distance: float = 22.0
@export var social_separation_push: float = 22.0
@export var social_repath_distance: float = 4.0

var target_position: Vector2 = Vector2.ZERO
var moving: bool = false
var social_target: Agent = null
var _last_velocity: Vector2 = Vector2.ZERO
var _last_social_anchor: Vector2 = Vector2.ZERO

# Para UI
var current_goal_label: String = ""
var last_reached_label: String = ""
var current_activity: String = ""

# Planner del día
# Array[Dictionary] con:
# { "segment": int, "time_label": String, "title": String, "detail": String }
var today_plan: Array = []

# =====================================================
# ESTADO INTERNO
# =====================================================

var needs: Dictionary = {"social": 0.5, "curiosity": 0.5}
var mood: Dictionary = {
	"happiness": 0.5,
	"anger": 0.0,
	"loneliness": 0.2,
	"anxiety": 0.1,
	"stress": 0.1
}

var long_memory: Array = []
var existential_state: float = 0.0
var awaiting_thought: bool = false

# relationships[other_agent_id] = { trust, resentment, affinity }
var relationships: Dictionary = {}
# affinities legacy: agent_id -> float (-1..1)
var affinities: Dictionary = {}

# =====================================================
# VISUAL
# =====================================================

@export var unique_tint_strength: float = 0.25
var _portrait_texture: Texture2D = null

# =====================================================
# HOVER (para UI)
# =====================================================

var _hover_area: Area2D = null
var _hover_shape: CollisionShape2D = null

# =====================================================
# READY / INIT
# =====================================================

func _ready() -> void:
	_ensure_needs()
	_ensure_mood()
	_setup_navigation_agent()
	call_deferred("_setup_hover_area")

func initialize(agent_data: AgentData) -> void:
	data = agent_data
	_ensure_needs()
	_ensure_mood()
	_apply_unique_tint()

# =====================================================
# UTIL
# =====================================================

func _to_int(v: Variant, default_value: int = 0) -> int:
	if v == null:
		return default_value
	var t: int = typeof(v)
	if t == TYPE_INT:
		return v
	if t == TYPE_FLOAT:
		return floori(float(v))
	if t == TYPE_STRING:
		return String(v).to_int()
	return default_value

func _to_float(v: Variant, default_value: float = 0.0) -> float:
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

func _safe_agent_id() -> String:
	if data != null and str(data.agent_id).strip_edges() != "":
		return str(data.agent_id)
	return get_agent_name()

# =====================================================
# UI HELPERS
# =====================================================

func get_agent_name() -> String:
	if data != null and data.agent_name.strip_edges() != "":
		return data.agent_name
	return String(name)

func get_gender() -> String:
	if data == null:
		return ""
	return str(data.gender)

func get_sociability() -> float:
	if data == null:
		return 0.5
	return clamp(_to_float(data.personality.get("sociability", 0.5), 0.5), 0.0, 1.0)

func get_portrait_texture() -> Texture2D:
	if _portrait_texture != null:
		return _portrait_texture

	if sprite == null or sprite.sprite_frames == null:
		return null

	var anim: String = sprite.animation
	if anim == "" or not sprite.sprite_frames.has_animation(anim):
		if sprite.sprite_frames.has_animation("Idle"):
			anim = "Idle"
		else:
			return null

	var cnt: int = _to_int(sprite.sprite_frames.get_frame_count(anim), 0)
	if cnt <= 0:
		return null

	var fr: int = clampi(_to_int(sprite.frame, 0), 0, cnt - 1)
	return sprite.sprite_frames.get_frame_texture(anim, fr)

# =====================================================
# TINTE ÚNICO
# =====================================================

func _apply_unique_tint() -> void:
	if sprite == null:
		return
	var key: String = get_agent_name()
	var h: int = abs(key.hash())
	var hue: float = float(h % 360) / 360.0
	var tint: Color = Color.from_hsv(hue, 0.35, 1.0, 1.0)
	var tint_strength: float = clampf(unique_tint_strength, 0.0, 1.0)
	sprite.modulate = Color(1, 1, 1, 1).lerp(tint, tint_strength)

# =====================================================
# SPRITESHEET
# =====================================================

func apply_spritesheet_character(sheet: Texture2D, sprite_variant: int, frame_size: Vector2i, frames_per_dir: int, _dir_order: Array[String], fps_walk: float) -> void:
	if sprite == null or sheet == null:
		return

	if frames_per_dir <= 0:
		frames_per_dir = 3
	if frame_size.x <= 0 or frame_size.y <= 0:
		frame_size = Vector2i(16, 16)

	var img: Image = sheet.get_image()
	if img == null:
		return

	var rows: int = maxi(1, floori(float(img.get_height()) / float(frame_size.y)))
	var cols: int = maxi(1, floori(float(img.get_width()) / float(frame_size.x)))

	sprite_variant = clampi(sprite_variant, 0, rows - 1)

	var frames: SpriteFrames = SpriteFrames.new()

	var anim_down: String = "Walk"
	var anim_left: String = "Walk_left"
	var anim_right: String = "Walk_right"
	var anim_up: String = "Walk_up"
	var anim_idle: String = "Idle"

	frames.add_animation(anim_down)
	frames.add_animation(anim_left)
	frames.add_animation(anim_right)
	frames.add_animation(anim_up)
	frames.add_animation(anim_idle)

	frames.set_animation_speed(anim_down, fps_walk)
	frames.set_animation_speed(anim_left, fps_walk)
	frames.set_animation_speed(anim_right, fps_walk)
	frames.set_animation_speed(anim_up, fps_walk)
	frames.set_animation_speed(anim_idle, 1.0)

	for dir_index in range(4):
		var base_col: int = dir_index * frames_per_dir
		for f in range(frames_per_dir):
			var col: int = base_col + f
			if col >= cols:
				continue

			var px: int = col * frame_size.x
			var py: int = sprite_variant * frame_size.y
			var region: Rect2i = Rect2i(px, py, frame_size.x, frame_size.y)

			var at: AtlasTexture = AtlasTexture.new()
			at.atlas = sheet
			at.region = region

			var anim_name: String = anim_down
			if dir_index == 1:
				anim_name = anim_left
			elif dir_index == 2:
				anim_name = anim_right
			elif dir_index == 3:
				anim_name = anim_up

			frames.add_frame(anim_name, at)

	var idle_region: Rect2i = Rect2i(0, sprite_variant * frame_size.y, frame_size.x, frame_size.y)
	var idle_at: AtlasTexture = AtlasTexture.new()
	idle_at.atlas = sheet
	idle_at.region = idle_region
	frames.add_frame(anim_idle, idle_at)

	sprite.sprite_frames = frames
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.play(anim_idle)
	sprite.frame = 0

# =====================================================
# HOVER AREA
# =====================================================

func _setup_hover_area() -> void:
	if _hover_area != null and is_instance_valid(_hover_area):
		return

	_hover_area = Area2D.new()
	_hover_area.name = "HoverArea"
	_hover_area.input_pickable = true
	add_child(_hover_area)

	_hover_shape = CollisionShape2D.new()
	_hover_shape.name = "HoverShape"
	_hover_area.add_child(_hover_shape)

	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 12.0
	_hover_shape.shape = circle

	if col_shape != null and col_shape.shape != null and col_shape.shape is CircleShape2D:
		var src: CircleShape2D = col_shape.shape as CircleShape2D
		var c: CircleShape2D = CircleShape2D.new()
		c.radius = maxf(src.radius, 12.0)
		_hover_shape.shape = c

	_hover_area.mouse_entered.connect(_on_mouse_entered)
	_hover_area.mouse_exited.connect(_on_mouse_exited)
	_hover_area.input_event.connect(_on_hover_input)

func _on_mouse_entered() -> void:
	if Engine.has_singleton("EventBus"):
		EventBus.emit_agent_hovered(self)

func _on_mouse_exited() -> void:
	if Engine.has_singleton("EventBus"):
		EventBus.emit_agent_unhovered(self)

func _on_hover_input(_vp: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if Engine.has_singleton("EventBus"):
				EventBus.emit_agent_clicked(self)
				EventBus.emit_agent_selected(self)
			get_viewport().set_input_as_handled()

# =====================================================
# NAVEGACIÓN
# =====================================================

func _setup_navigation_agent() -> void:
	if nav == null:
		return
	nav.path_desired_distance = 10.0
	nav.target_desired_distance = maxf(interaction_distance, social_min_distance)
	nav.avoidance_enabled = false

func _personal_offset(radius: float) -> Vector2:
	var key: String = get_agent_name()
	var h: int = abs(key.hash())
	var angle: float = float(h % 360) * deg_to_rad(1.0)
	return Vector2(cos(angle), sin(angle)) * radius

func _social_angle_with(target: Agent) -> float:
	var key: String = _safe_agent_id() + "|" + target._safe_agent_id()
	var h: int = abs(key.hash())
	return deg_to_rad(float(h % 360))

func _get_social_anchor(target: Agent) -> Vector2:
	if target == null or not is_instance_valid(target):
		return global_position

	var min_radius: float = maxf(social_min_distance + 4.0, interaction_distance + 8.0)
	var radius: float = maxf(social_ring_radius, min_radius)
	var angle: float = _social_angle_with(target)
	return target.global_position + Vector2(cos(angle), sin(angle)) * radius

func _nav_map_ready() -> bool:
	var map_rid: RID = get_world_2d().navigation_map
	if not map_rid.is_valid():
		return false
	return NavigationServer2D.map_get_iteration_id(map_rid) > 0

# =====================================================
# PHYSICS
# =====================================================

func _physics_process(delta: float) -> void:
	if social_target != null and is_instance_valid(social_target):
		var desired_social_anchor: Vector2 = _get_social_anchor(social_target)
		if desired_social_anchor.distance_to(_last_social_anchor) > social_repath_distance:
			_last_social_anchor = desired_social_anchor
			_set_destination(desired_social_anchor, false)

	if not moving:
		_last_velocity = Vector2.ZERO
		_update_animation(Vector2.ZERO)
		if social_target != null and is_instance_valid(social_target):
			_apply_soft_social_separation(delta)
		return

	var velocity: Vector2
	if nav != null and nav.is_inside_tree() and _nav_map_ready():
		velocity = _step_navigation(delta)
	else:
		velocity = _step_direct(delta)

	_last_velocity = velocity
	_update_animation(velocity)

	if social_target != null and is_instance_valid(social_target):
		_apply_soft_social_separation(delta)

	if unstuck_enabled:
		_try_unstuck(delta)

	if clamp_to_bounds:
		global_position = Vector2(
			clampf(global_position.x, world_min.x, world_max.x),
			clampf(global_position.y, world_min.y, world_max.y)
		)

# =====================================================
# MOVIMIENTO
# =====================================================

func _step_navigation(delta: float) -> Vector2:
	var arrival_dist: float = interaction_distance
	if social_target != null and is_instance_valid(social_target):
		arrival_dist = maxf(social_min_distance * 0.85, interaction_distance)

	if global_position.distance_to(target_position) <= arrival_dist:
		moving = false
		_on_reached_destination()
		return Vector2.ZERO

	if nav.is_navigation_finished():
		var rec: Dictionary = _get_closest_navigable(target_position)
		if bool(rec.get("ok", false)):
			nav.target_position = Vector2(rec.get("pos", global_position))
		else:
			return _step_direct(delta)

	var next_point: Vector2 = nav.get_next_path_position()
	var dir: Vector2 = next_point - global_position
	var dist: float = dir.length()
	if dist <= 0.001:
		return Vector2.ZERO

	var step: float = speed * delta
	if dist <= step:
		global_position = next_point
		return Vector2.ZERO

	var vel: Vector2 = dir / dist * speed
	global_position += vel * delta
	return vel

func _step_direct(delta: float) -> Vector2:
	var arrival_dist: float = interaction_distance
	if social_target != null and is_instance_valid(social_target):
		arrival_dist = maxf(social_min_distance * 0.85, interaction_distance)

	var dir: Vector2 = target_position - global_position
	var dist: float = dir.length()

	if dist <= arrival_dist:
		moving = false
		_on_reached_destination()
		return Vector2.ZERO

	var step: float = speed * delta
	if dist <= step:
		global_position = target_position
		moving = false
		_on_reached_destination()
		return Vector2.ZERO

	var vel: Vector2 = dir / dist * speed
	global_position += vel * delta
	return vel

func _apply_soft_social_separation(delta: float) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return

	var push: Vector2 = Vector2.ZERO
	var neighbor_count: int = 0

	for child in parent_node.get_children():
		if child == self:
			continue
		if not (child is Agent):
			continue

		var other: Agent = child as Agent
		if other == null or not is_instance_valid(other):
			continue

		var diff: Vector2 = global_position - other.global_position
		var dist: float = diff.length()

		if dist <= 0.001:
			var angle: float = deg_to_rad(float(abs((_safe_agent_id() + "|" + other._safe_agent_id()).hash()) % 360))
			diff = Vector2(cos(angle), sin(angle))
			dist = 0.001

		if dist < social_min_distance:
			var strength: float = 1.0 - (dist / social_min_distance)
			push += diff.normalized() * strength
			neighbor_count += 1

	if neighbor_count <= 0:
		return

	var offset: Vector2 = push.normalized() * social_separation_push * delta
	global_position += offset

	if clamp_to_bounds:
		global_position = Vector2(
			clampf(global_position.x, world_min.x, world_max.x),
			clampf(global_position.y, world_min.y, world_max.y)
		)

func _get_closest_navigable(pos: Vector2) -> Dictionary:
	var result: Dictionary = {"ok": false, "pos": global_position}

	var map_rid: RID = get_world_2d().navigation_map
	if not map_rid.is_valid():
		return result

	if NavigationServer2D.map_get_iteration_id(map_rid) <= 0:
		return result

	var p: Vector2 = NavigationServer2D.map_get_closest_point(map_rid, pos)
	if p.distance_to(pos) > 400.0:
		return result

	result["ok"] = true
	result["pos"] = p
	return result

func _set_destination(pos: Vector2, use_jitter: bool = true) -> void:
	target_position = pos

	if use_jitter and destination_jitter > 0.0:
		target_position += Vector2(
			randf_range(-destination_jitter, destination_jitter),
			randf_range(-destination_jitter, destination_jitter)
		)

	if clamp_to_bounds:
		target_position.x = clampf(target_position.x, world_min.x, world_max.x)
		target_position.y = clampf(target_position.y, world_min.y, world_max.y)

	if nav != null and nav.is_inside_tree() and _nav_map_ready():
		var safe_res: Dictionary = _get_closest_navigable(target_position)
		if bool(safe_res.get("ok", false)):
			nav.target_position = Vector2(safe_res.get("pos", global_position))
			moving = true
			return

	moving = true

# =====================================================
# API DE MOVIMIENTO
# =====================================================

func move_to_position(pos: Vector2, label: String = "") -> void:
	social_target = null
	current_goal_label = label
	current_activity = ""
	_set_destination(pos, true)

func start_wandering() -> void:
	social_target = null
	current_goal_label = "Explorar"
	current_activity = "Explorando"

	var desired: Vector2 = global_position + Vector2(randf_range(-220, 220), randf_range(-220, 220))
	if clamp_to_bounds:
		desired.x = clampf(desired.x, world_min.x, world_max.x)
		desired.y = clampf(desired.y, world_min.y, world_max.y)
	_set_destination(desired, true)

func set_social_target(target: Agent) -> void:
	if target == null or not is_instance_valid(target):
		return

	social_target = target
	current_goal_label = "Visitar a " + target.get_agent_name()
	current_activity = "Socializando"

	var desired: Vector2 = _get_social_anchor(target)
	_last_social_anchor = desired
	_set_destination(desired, false)

	remember("Decidió visitar a " + target.get_agent_name())

# =====================================================
# ANIMACIONES
# =====================================================

func _update_animation(velocity: Vector2) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return

	if velocity.length() < 0.1:
		_play_anim("Idle")
		return

	var dir: Vector2 = velocity.normalized()
	if absf(dir.x) > absf(dir.y):
		_play_anim("Walk_right" if dir.x > 0.0 else "Walk_left")
	else:
		_play_anim("Walk" if dir.y > 0.0 else "Walk_up")

func _play_anim(anim: String) -> void:
	if sprite.animation != anim and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)

func _try_unstuck(delta: float) -> void:
	if col_shape == null:
		return
	if _last_velocity.length() > 5.0:
		return
	var push_dir: Vector2 = Vector2(randf_range(-1, 1), randf_range(-1, 1))
	if push_dir.length() < 0.2:
		return
	global_position += push_dir.normalized() * (unstuck_push * delta)

# =====================================================
# LLEGADA / INTERACCIÓN
# =====================================================

func _on_reached_destination() -> void:
	if social_target != null and is_instance_valid(social_target):
		if global_position.distance_to(social_target.global_position) < social_min_distance * 0.55:
			var corrected: Vector2 = _get_social_anchor(social_target)
			_last_social_anchor = corrected
			_set_destination(corrected, false)
			return

	last_reached_label = current_goal_label
	current_goal_label = ""

	if social_target != null and is_instance_valid(social_target):
		_execute_social_interaction(social_target)
		social_target = null
		current_activity = ""

# =====================================================
# NEEDS / MOOD
# =====================================================

func evaluate_needs() -> void:
	_ensure_needs()
	_ensure_mood()

	var old_social: float = _to_float(needs.get("social", 0.5), 0.5)
	var old_cur: float = _to_float(needs.get("curiosity", 0.5), 0.5)

	needs["social"] = clampf(old_social + randf_range(-0.08, 0.18), 0.0, 1.0)
	needs["curiosity"] = clampf(old_cur + randf_range(-0.06, 0.14), 0.0, 1.0)

	mood["anger"] = maxf(0.0, _to_float(mood.get("anger", 0.0), 0.0) - 0.05)
	mood["anxiety"] = maxf(0.0, _to_float(mood.get("anxiety", 0.1), 0.1) - 0.02)
	mood["stress"] = maxf(0.0, _to_float(mood.get("stress", 0.1), 0.1) - 0.02)
	mood["loneliness"] = clampf(_to_float(mood.get("loneliness", 0.2), 0.2) + 0.02, 0.0, 1.0)

	_update_mood()

	if Engine.has_singleton("EventBus"):
		EventBus.emit_need_changed(self, "social", _to_float(needs["social"], 0.5))
		EventBus.emit_need_changed(self, "curiosity", _to_float(needs["curiosity"], 0.5))
		EventBus.emit_mood_changed(self, "happiness", _to_float(mood.get("happiness", 0.5), 0.5))

func _update_mood() -> void:
	if data == null:
		return
	var stability: float = clampf(_to_float(data.personality.get("stability", 0.7), 0.7), 0.0, 1.0)

	var happiness_delta: float = 0.0
	happiness_delta -= _to_float(mood.get("loneliness", 0.0), 0.0) * 0.18
	happiness_delta -= _to_float(mood.get("anxiety", 0.0), 0.0) * 0.18
	happiness_delta -= _to_float(mood.get("stress", 0.0), 0.0) * 0.14
	happiness_delta -= _to_float(mood.get("anger", 0.0), 0.0) * 0.24
	happiness_delta *= stability

	mood["happiness"] = clampf(_to_float(mood.get("happiness", 0.5), 0.5) + happiness_delta, 0.0, 1.0)

# =====================================================
# PLANNER
# =====================================================

func clear_today_plan() -> void:
	today_plan.clear()

func add_plan_item(text: String) -> void:
	var raw: String = str(text).strip_edges()
	if raw == "":
		return

	var parsed: Dictionary = _parse_plan_text(raw)
	today_plan.append(parsed)

func add_plan_entry(segment: int, time_label: String, title: String, detail: String = "") -> void:
	var item: Dictionary = {
		"segment": clampi(segment, 0, 3),
		"time_label": time_label,
		"title": title.strip_edges(),
		"detail": detail.strip_edges()
	}
	today_plan.append(item)

func _parse_plan_text(raw: String) -> Dictionary:
	var segment: int = 0
	var time_label: String = "Mañana"
	var title: String = raw
	var detail: String = ""

	var labels_map: Dictionary = {
		"mañana": 0,
		"tarde": 1,
		"atardecer": 2,
		"noche": 3
	}

	var lower: String = raw.to_lower()

	for key in labels_map.keys():
		if lower.find(key) != -1:
			segment = int(labels_map[key])
			time_label = _segment_to_label(segment)
			break

	var closing_idx: int = raw.find(")")
	if raw.begins_with("(") and closing_idx != -1 and closing_idx + 1 < raw.length():
		title = raw.substr(closing_idx + 1, raw.length()).strip_edges()

	var separator_idx: int = title.find(" - ")
	if separator_idx != -1:
		detail = title.substr(separator_idx + 3, title.length()).strip_edges()
		title = title.substr(0, separator_idx).strip_edges()

	return {
		"segment": segment,
		"time_label": time_label,
		"title": title,
		"detail": detail
	}

func _segment_to_label(segment: int) -> String:
	match segment:
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

func execute_planned_segment(segment: int, ai_manager: Node) -> void:
	if moving:
		return

	var item: Dictionary = {}
	for it in today_plan:
		if _to_int(it.get("segment", -1), -1) == segment:
			item = it
			break

	if item.is_empty():
		start_wandering()
		return

	var title: String = str(item.get("title", "Explorar"))
	var detail: String = str(item.get("detail", ""))

	current_activity = title
	if detail != "":
		current_goal_label = title + " · " + detail
	else:
		current_goal_label = title

	if title == "Socializar" and ai_manager != null and ai_manager.has_method("get_random_agent"):
		var other: Agent = ai_manager.call("get_random_agent")
		if other != null and other != self:
			set_social_target(other)
			return

	if title == "Explorar" or title == "Curiosear" or title == "Dar una vuelta":
		start_wandering()
		return

	if title == "Reflexionar":
		moving = false
		remember("Se quedó en calma pensando un momento.")
		return

	if title == "Descansar" or title == "Descansar / charlar":
		moving = false
		return

	start_wandering()

func execute_next_task(ai_manager: Node) -> void:
	var segment: int = _guess_current_segment()
	execute_planned_segment(segment, ai_manager)

func _guess_current_segment() -> int:
	var clock: Node = get_tree().get_root().find_child("WorldClock", true, false)
	if clock != null:
		if "current_time_segment" in clock:
			return clampi(int(clock.get("current_time_segment")), 0, 3)
	return 0

# =====================================================
# RELACIONES
# =====================================================

func set_affinity_with(other: Agent, affinity_value: float) -> void:
	if other == null or not is_instance_valid(other) or other.data == null:
		return
	var oid: String = str(other.data.agent_id)
	relationships[oid] = {
		"trust": clampf(0.5 + affinity_value * 0.25, 0.0, 1.0),
		"resentment": clampf(-affinity_value * 0.15, 0.0, 1.0),
		"affinity": clampf((affinity_value + 1.0) * 0.5, 0.0, 1.0)
	}
	affinities[oid] = clampf(affinity_value, -1.0, 1.0)

func _ensure_relationship(other_id: String) -> void:
	if not relationships.has(other_id):
		relationships[other_id] = {
			"trust": 0.5,
			"resentment": 0.0,
			"affinity": 0.5
		}

func apply_interaction_with(other: Agent, positive: bool, strength: float = 0.1) -> void:
	if other == null or not is_instance_valid(other) or other.data == null:
		return
	var oid: String = str(other.data.agent_id)
	_ensure_relationship(oid)

	var rel: Dictionary = relationships[oid]
	if positive:
		rel["trust"] = clampf(_to_float(rel.get("trust", 0.5), 0.5) + strength, 0.0, 1.0)
		rel["affinity"] = clampf(_to_float(rel.get("affinity", 0.5), 0.5) + strength * 0.8, 0.0, 1.0)
		rel["resentment"] = clampf(_to_float(rel.get("resentment", 0.0), 0.0) - strength * 0.6, 0.0, 1.0)
	else:
		rel["resentment"] = clampf(_to_float(rel.get("resentment", 0.0), 0.0) + strength * 1.2, 0.0, 1.0)
		rel["trust"] = clampf(_to_float(rel.get("trust", 0.5), 0.5) - strength * 0.8, 0.0, 1.0)
		rel["affinity"] = clampf(_to_float(rel.get("affinity", 0.5), 0.5) - strength * 0.7, 0.0, 1.0)
		mood["anger"] = clampf(_to_float(mood.get("anger", 0.0), 0.0) + 0.12, 0.0, 1.0)
		mood["stress"] = clampf(_to_float(mood.get("stress", 0.1), 0.1) + 0.08, 0.0, 1.0)

	relationships[oid] = rel
	affinities[oid] = (_to_float(rel.get("affinity", 0.5), 0.5) * 2.0) - 1.0

func _execute_social_interaction(other: Agent) -> void:
	var positive: bool = (randf() < 0.75)
	var delta: float = randf_range(0.05, 0.14) if positive else randf_range(0.06, 0.18)

	mood["loneliness"] = maxf(0.0, _to_float(mood.get("loneliness", 0.0), 0.0) - 0.22)
	mood["happiness"] = clampf(_to_float(mood.get("happiness", 0.5), 0.5) + (0.06 if positive else -0.03), 0.0, 1.0)

	apply_interaction_with(other, positive, delta)
	remember("Habló con " + other.get_agent_name() + (" (bien)" if positive else " (tenso)"))

	if Engine.has_singleton("EventBus"):
		EventBus.emit_social_interaction(self, other, (delta if positive else -delta))

# =====================================================
# MEMORIA
# =====================================================

func remember(event_text: String) -> void:
	long_memory.append({
		"text": event_text,
		"timestamp": Time.get_unix_time_from_system()
	})
	if long_memory.size() > 250:
		long_memory.pop_front()

# =====================================================
# UTIL
# =====================================================

func _ensure_needs() -> void:
	if needs == null:
		needs = {}
	if not needs.has("social"):
		needs["social"] = 0.5
	if not needs.has("curiosity"):
		needs["curiosity"] = 0.5

func _ensure_mood() -> void:
	if mood == null:
		mood = {}
	if not mood.has("happiness"):
		mood["happiness"] = 0.5
	if not mood.has("anger"):
		mood["anger"] = 0.0
	if not mood.has("loneliness"):
		mood["loneliness"] = 0.2
	if not mood.has("anxiety"):
		mood["anxiety"] = 0.1
	if not mood.has("stress"):
		mood["stress"] = 0.1
