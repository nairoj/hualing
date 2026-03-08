extends CharacterBody2D

@export var move_speed: float = 110.0
@export var follow_slot_offset: Vector2 = Vector2(-44.0, 18.0)
@export var follow_start_distance: float = 52.0
@export var follow_stop_distance: float = 28.0
@export var teleport_to_player_distance: float = 420.0

@export var attack_damage: int = 8
@export var attack_range: float = 30.0
@export var attack_duration: float = 0.16
@export var attack_cooldown: float = 0.55
@export var attack_hitbox_offset: float = 22.0
@export var chase_leash_distance: float = 220.0

@export var player_group: StringName = &"player"
@export var enemy_group: StringName = &"enemy"

@export_dir var sprite_sheet_dir: String = "res://Asset/Sprites/Agui_spritesheet/"
@export var sprite_prefix: String = "agui"
@export var frame_width: int = 64
@export var auto_build_animations: bool = true

@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var detection_area: Area2D = get_node_or_null("DetectionArea")
@onready var detection_shape: CollisionShape2D = get_node_or_null("DetectionArea/CollisionShape2D")
@onready var attack_area: Area2D = get_node_or_null("AttackArea")
@onready var attack_shape: CollisionShape2D = get_node_or_null("AttackArea/CollisionShape2D")

var _player: Node2D = null
var _current_target: Node2D = null
var _targets: Array[Node2D] = []
var _hit_target_ids: Dictionary = {}

var _is_attacking: bool = false
var _attack_time_left: float = 0.0
var _cooldown_left: float = 0.0
var _last_facing: Vector2 = Vector2.RIGHT
var _last_cardinal_facing: Vector2 = Vector2.RIGHT

const ANIM_IDLE_DOWN := "idle_down"
const ANIM_IDLE_UP := "idle_up"
const ANIM_IDLE_LEFT := "idle_left"
const ANIM_IDLE_RIGHT := "idle_right"
const ANIM_MOVE_DOWN := "move_down"
const ANIM_MOVE_UP := "move_up"
const ANIM_MOVE_LEFT := "move_left"
const ANIM_MOVE_RIGHT := "move_right"
const ANIM_ATTACK_LEFT := "attack_left"
const ANIM_ATTACK_RIGHT := "attack_right"

func _ready() -> void:
	if not is_in_group("partner"):
		add_to_group("partner")

	if auto_build_animations:
		_build_default_animations()

	_player = _find_player()
	_ensure_collision_exceptions()
	_setup_detection_area()
	_setup_attack_area()
	_update_facing(Vector2.RIGHT)
	_update_animation()

func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_refresh_player_if_needed()
	_cleanup_targets()
	_current_target = _pick_target()

	if _player == null:
		velocity = Vector2.ZERO
		move_and_slide()
		_update_animation()
		return

	if _is_attacking:
		velocity = Vector2.ZERO
	elif _current_target != null:
		_process_combat()
	else:
		_process_follow()

	move_and_slide()
	_update_animation()

func _process_follow() -> void:
	var anchor := _player.global_position + follow_slot_offset
	var to_anchor := anchor - global_position
	var distance := to_anchor.length()

	if distance >= teleport_to_player_distance:
		global_position = anchor
		velocity = Vector2.ZERO
		return

	if distance > follow_start_distance:
		velocity = to_anchor.normalized() * move_speed
		_update_facing(to_anchor)
	elif distance < follow_stop_distance:
		velocity = Vector2.ZERO

func _process_combat() -> void:
	if _current_target == null:
		velocity = Vector2.ZERO
		return

	if global_position.distance_to(_player.global_position) > chase_leash_distance:
		_current_target = null
		velocity = Vector2.ZERO
		return

	var to_target := _current_target.global_position - global_position
	var distance := to_target.length()

	if distance <= attack_range and _cooldown_left <= 0.0:
		_start_attack(to_target)
		velocity = Vector2.ZERO
		return

	velocity = to_target.normalized() * move_speed
	_update_facing(to_target)

func _start_attack(direction: Vector2) -> void:
	_is_attacking = true
	_attack_time_left = attack_duration
	_cooldown_left = attack_duration + attack_cooldown
	_hit_target_ids.clear()
	_update_facing(direction)
	_enable_attack_hitbox()

func _update_timers(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(0.0, _cooldown_left - delta)

	if _is_attacking:
		_attack_time_left -= delta
		if _attack_time_left <= 0.0:
			_is_attacking = false
			_disable_attack_hitbox()

func _refresh_player_if_needed() -> void:
	if _player != null and is_instance_valid(_player) and _player.is_inside_tree():
		return
	_player = _find_player()
	_ensure_collision_exceptions()

func _find_player() -> Node2D:
	return get_tree().get_first_node_in_group(player_group) as Node2D

func _ensure_collision_exceptions() -> void:
	var self_body := self as PhysicsBody2D
	if self_body == null:
		return

	var player_body := _player as PhysicsBody2D
	if player_body != null:
		self_body.add_collision_exception_with(player_body)
		player_body.add_collision_exception_with(self_body)

	for node in get_tree().get_nodes_in_group("partner"):
		var partner_body := node as PhysicsBody2D
		if partner_body == null or partner_body == self_body:
			continue
		self_body.add_collision_exception_with(partner_body)
		partner_body.add_collision_exception_with(self_body)

func _setup_detection_area() -> void:
	if detection_area == null or detection_shape == null:
		push_warning("DetectionArea/CollisionShape2D not found. Partner cannot detect enemies.")
		return

	if not detection_area.body_entered.is_connected(_on_detection_body_entered):
		detection_area.body_entered.connect(_on_detection_body_entered)
	if not detection_area.body_exited.is_connected(_on_detection_body_exited):
		detection_area.body_exited.connect(_on_detection_body_exited)

func _setup_attack_area() -> void:
	if attack_area == null or attack_shape == null:
		push_warning("AttackArea/CollisionShape2D not found. Partner cannot deal damage.")
		return

	attack_area.monitoring = false
	attack_area.monitorable = false
	attack_shape.disabled = true
	if not attack_area.body_entered.is_connected(_on_attack_area_body_entered):
		attack_area.body_entered.connect(_on_attack_area_body_entered)

func _enable_attack_hitbox() -> void:
	if attack_area == null or attack_shape == null:
		return
	attack_area.position = _last_facing.normalized() * attack_hitbox_offset
	attack_shape.disabled = false
	attack_area.monitoring = true
	attack_area.monitorable = true

func _disable_attack_hitbox() -> void:
	if attack_area == null or attack_shape == null:
		return
	attack_area.monitoring = false
	attack_area.monitorable = false
	attack_shape.disabled = true

func _on_detection_body_entered(body: Node) -> void:
	if not _is_enemy(body):
		return
	var enemy := body as Node2D
	if enemy == null:
		return
	if not _targets.has(enemy):
		_targets.append(enemy)

func _on_detection_body_exited(body: Node) -> void:
	var enemy := body as Node2D
	if enemy == null:
		return
	_targets.erase(enemy)
	if _current_target == enemy:
		_current_target = null

func _on_attack_area_body_entered(body: Node) -> void:
	if not _is_attacking or not _is_enemy(body):
		return

	var target_id := body.get_instance_id()
	if _hit_target_ids.has(target_id):
		return
	_hit_target_ids[target_id] = true

	if body.has_method("take_damage"):
		body.call("take_damage", attack_damage)

func _is_enemy(node: Node) -> bool:
	if node == null:
		return false
	if node == self or node == _player:
		return false
	return node.is_in_group(enemy_group)

func _cleanup_targets() -> void:
	var valid: Array[Node2D] = []
	for target in _targets:
		if _is_valid_target(target):
			valid.append(target)
	_targets = valid

func _pick_target() -> Node2D:
	var best_target: Node2D = null
	var best_distance_sq := INF

	for target in _targets:
		if not _is_valid_target(target):
			continue
		var d2 := global_position.distance_squared_to(target.global_position)
		if d2 < best_distance_sq:
			best_distance_sq = d2
			best_target = target

	return best_target

func _is_valid_target(target: Node2D) -> bool:
	if target == null:
		return false
	if not is_instance_valid(target):
		return false
	if not target.is_inside_tree():
		return false
	return target.is_in_group(enemy_group)

func _update_facing(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return
	_last_facing = direction.normalized()
	_last_cardinal_facing = _to_cardinal(direction)

func _to_cardinal(direction: Vector2) -> Vector2:
	if absf(direction.x) > absf(direction.y):
		return Vector2.RIGHT if direction.x >= 0.0 else Vector2.LEFT
	return Vector2.DOWN if direction.y >= 0.0 else Vector2.UP

func _update_animation() -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return

	if _is_attacking:
		if _last_cardinal_facing == Vector2.LEFT:
			_play_if_exists(ANIM_ATTACK_LEFT, ANIM_MOVE_LEFT)
		else:
			_play_if_exists(ANIM_ATTACK_RIGHT, ANIM_MOVE_RIGHT)
		return

	var moving := velocity.length_squared() > 1.0
	if moving:
		match _last_cardinal_facing:
			Vector2.LEFT:
				_play_if_exists(ANIM_MOVE_LEFT, ANIM_IDLE_LEFT)
			Vector2.RIGHT:
				_play_if_exists(ANIM_MOVE_RIGHT, ANIM_IDLE_RIGHT)
			Vector2.UP:
				_play_if_exists(ANIM_MOVE_UP, ANIM_IDLE_UP)
			_:
				_play_if_exists(ANIM_MOVE_DOWN, ANIM_IDLE_DOWN)
		return

	match _last_cardinal_facing:
		Vector2.LEFT:
			_play_if_exists(ANIM_IDLE_LEFT, ANIM_IDLE_DOWN)
		Vector2.RIGHT:
			_play_if_exists(ANIM_IDLE_RIGHT, ANIM_IDLE_DOWN)
		Vector2.UP:
			_play_if_exists(ANIM_IDLE_UP, ANIM_IDLE_DOWN)
		_:
			_play_if_exists(ANIM_IDLE_DOWN, ANIM_IDLE_RIGHT)

func _play_if_exists(preferred: StringName, fallback: StringName) -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return
	var frames := animated_sprite.sprite_frames
	if frames.has_animation(preferred):
		if animated_sprite.animation != preferred or not animated_sprite.is_playing():
			animated_sprite.play(preferred)
		return
	if frames.has_animation(fallback):
		if animated_sprite.animation != fallback or not animated_sprite.is_playing():
			animated_sprite.play(fallback)

func _build_default_animations() -> void:
	if animated_sprite == null:
		push_warning("AnimatedSprite2D not found on partner.")
		return

	if animated_sprite.sprite_frames == null:
		animated_sprite.sprite_frames = SpriteFrames.new()
	var frames := animated_sprite.sprite_frames

	_add_action_animation(frames, ANIM_IDLE_DOWN, "idle", "d", 6.0, true)
	_add_action_animation(frames, ANIM_IDLE_UP, "idle", "u", 6.0, true)
	_add_action_animation(frames, ANIM_IDLE_LEFT, "idle", "l", 6.0, true)
	_add_action_animation(frames, ANIM_IDLE_RIGHT, "idle", "r", 6.0, true)

	_add_action_animation(frames, ANIM_MOVE_DOWN, "walk", "d", 9.0, true)
	_add_action_animation(frames, ANIM_MOVE_UP, "walk", "u", 9.0, true)
	_add_action_animation(frames, ANIM_MOVE_LEFT, "walk", "l", 9.0, true)
	_add_action_animation(frames, ANIM_MOVE_RIGHT, "walk", "r", 9.0, true)

	_add_action_animation(frames, ANIM_ATTACK_LEFT, "attack", "l", 12.0, false)
	_add_action_animation(frames, ANIM_ATTACK_RIGHT, "attack", "r", 12.0, false)

func _add_action_animation(frames: SpriteFrames, animation_name: StringName, action: String, direction: String, fps: float, loop: bool) -> void:
	if frames.has_animation(animation_name):
		return

	var texture := _load_action_texture(action, direction)
	if texture == null:
		return

	var frame_count: int = int(floor(float(texture.get_width()) / float(frame_width)))
	if frame_count <= 0:
		return

	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, fps)
	frames.set_animation_loop(animation_name, loop)

	for i in frame_count:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(float(i * frame_width), 0.0, float(frame_width), float(texture.get_height()))
		frames.add_frame(animation_name, atlas)

func _load_action_texture(action: String, direction: String) -> Texture2D:
	for path in _candidate_paths(action, direction):
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null

func _candidate_paths(action: String, direction: String) -> Array[String]:
	var dir_norm := _normalized_dir(sprite_sheet_dir)
	var result: Array[String] = []

	var prefixes := [
		sprite_prefix,
		sprite_prefix.to_lower(),
		_capitalize_word(sprite_prefix),
		sprite_prefix.to_upper()
	]
	var actions := [action.to_lower(), _capitalize_word(action), action.to_upper()]
	var dirs := [direction.to_lower(), direction.to_upper()]

	for p in prefixes:
		if p.is_empty():
			continue
		for a in actions:
			for d in dirs:
				var file_name := "%s_%s_%s.png" % [p, a, d]
				var full_path := dir_norm + file_name
				if not result.has(full_path):
					result.append(full_path)

	return result

func _normalized_dir(raw_dir: String) -> String:
	if raw_dir.ends_with("/"):
		return raw_dir
	return raw_dir + "/"

func _capitalize_word(s: String) -> String:
	if s.is_empty():
		return s
	return s.substr(0, 1).to_upper() + s.substr(1).to_lower()
