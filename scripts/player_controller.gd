extends CharacterBody2D

@export var move_speed: float = 130.0
@export var attack_duration: float = 0.22
@export var attack_cooldown: float = 0.12
@export var attack_hitbox_offset: float = 28.0
@export var attack_damage: int = 12
@export var frame_width: int = 64
@export var auto_build_animations: bool = true

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Area2D = get_node_or_null("AttackArea")
@onready var attack_shape: CollisionShape2D = get_node_or_null("AttackArea/CollisionShape2D")

var _is_attacking: bool = false
var _attack_time_left: float = 0.0
var _cooldown_left: float = 0.0
var _last_facing: Vector2 = Vector2.DOWN
var _last_horizontal_sign: int = 1

const INPUT_MOVE_UP := "move_up"
const INPUT_MOVE_DOWN := "move_down"
const INPUT_MOVE_LEFT := "move_left"
const INPUT_MOVE_RIGHT := "move_right"
const INPUT_ATTACK := "attack"

const ANIM_IDLE_DOWN := "idle_down"
const ANIM_IDLE_UP := "idle_up"
const ANIM_IDLE_LEFT := "idle_left"
const ANIM_IDLE_RIGHT := "idle_right"
const ANIM_WALK_DOWN := "walk_down"
const ANIM_WALK_UP := "walk_up"
const ANIM_WALK_LEFT := "walk_left"
const ANIM_WALK_RIGHT := "walk_right"
const ANIM_ATTACK_LEFT := "attack_left"
const ANIM_ATTACK_RIGHT := "attack_right"

const PLAYER_SPRITE_DIR := "res://Asset/Sprites/player_spritesheet/"

func _ready() -> void:
	if not is_in_group("player"):
		add_to_group("player")
	_ensure_default_input_actions()
	if auto_build_animations:
		_build_default_animations()
	_setup_attack_area()
	_play_idle_animation()

func _physics_process(delta: float) -> void:
	_update_attack_timers(delta)

	if _can_start_attack() and Input.is_action_just_pressed(INPUT_ATTACK):
		_start_attack()

	if _is_attacking:
		velocity = Vector2.ZERO
	else:
		_move_player()

	move_and_slide()
	_update_animation()

func _move_player() -> void:
	var input_vector := Input.get_vector(INPUT_MOVE_LEFT, INPUT_MOVE_RIGHT, INPUT_MOVE_UP, INPUT_MOVE_DOWN)
	velocity = input_vector * move_speed

	if input_vector != Vector2.ZERO:
		_last_facing = _to_cardinal(input_vector)
		if absf(input_vector.x) > 0.001:
			_last_horizontal_sign = 1 if input_vector.x > 0.0 else -1

func _to_cardinal(direction: Vector2) -> Vector2:
	if absf(direction.x) > absf(direction.y):
		return Vector2.RIGHT if direction.x >= 0.0 else Vector2.LEFT
	return Vector2.DOWN if direction.y >= 0.0 else Vector2.UP

func _can_start_attack() -> bool:
	return not _is_attacking and _cooldown_left <= 0.0

func _start_attack() -> void:
	_is_attacking = true
	_attack_time_left = attack_duration
	_cooldown_left = attack_duration + attack_cooldown
	velocity = Vector2.ZERO
	_enable_attack_hitbox()
	_play_attack_animation()

func _update_attack_timers(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(0.0, _cooldown_left - delta)
	if _is_attacking:
		_attack_time_left -= delta
		if _attack_time_left <= 0.0:
			_is_attacking = false
			_disable_attack_hitbox()

func _setup_attack_area() -> void:
	if attack_area == null or attack_shape == null:
		push_warning("AttackArea/CollisionShape2D not found. Attack hit detection is disabled.")
		return
	attack_area.monitoring = false
	attack_area.monitorable = false
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	attack_shape.disabled = true

func _enable_attack_hitbox() -> void:
	if attack_area == null or attack_shape == null:
		return
	attack_area.position = _attack_offset_by_facing(_last_facing)
	attack_shape.disabled = false
	attack_area.monitoring = true
	attack_area.monitorable = true

func _disable_attack_hitbox() -> void:
	if attack_area == null or attack_shape == null:
		return
	attack_area.monitoring = false
	attack_area.monitorable = false
	attack_shape.disabled = true

func _attack_offset_by_facing(facing: Vector2) -> Vector2:
	match facing:
		Vector2.LEFT:
			return Vector2.LEFT * attack_hitbox_offset
		Vector2.RIGHT:
			return Vector2.RIGHT * attack_hitbox_offset
		Vector2.UP:
			return Vector2.UP * attack_hitbox_offset
		_:
			return Vector2.DOWN * attack_hitbox_offset

func _on_attack_area_body_entered(body: Node) -> void:
	if body == self:
		return
	if body.has_method("take_damage"):
		body.call("take_damage", attack_damage)

func _update_animation() -> void:
	if _is_attacking:
		return
	if velocity == Vector2.ZERO:
		_play_idle_animation()
		return

	match _last_facing:
		Vector2.LEFT:
			_play_if_exists(ANIM_WALK_LEFT, ANIM_IDLE_LEFT)
		Vector2.RIGHT:
			_play_if_exists(ANIM_WALK_RIGHT, ANIM_IDLE_RIGHT)
		Vector2.UP:
			_play_if_exists(ANIM_WALK_UP, ANIM_IDLE_UP)
		_:
			_play_if_exists(ANIM_WALK_DOWN, ANIM_IDLE_DOWN)

func _play_idle_animation() -> void:
	match _last_facing:
		Vector2.LEFT:
			_play_if_exists(ANIM_IDLE_LEFT, ANIM_IDLE_DOWN)
		Vector2.RIGHT:
			_play_if_exists(ANIM_IDLE_RIGHT, ANIM_IDLE_DOWN)
		Vector2.UP:
			_play_if_exists(ANIM_IDLE_UP, ANIM_IDLE_DOWN)
		_:
			_play_if_exists(ANIM_IDLE_DOWN, ANIM_IDLE_RIGHT)

func _play_attack_animation() -> void:
	var prefer_left := _last_horizontal_sign < 0
	if prefer_left:
		_play_if_exists(ANIM_ATTACK_LEFT, ANIM_ATTACK_RIGHT)
	else:
		_play_if_exists(ANIM_ATTACK_RIGHT, ANIM_ATTACK_LEFT)

func _play_if_exists(preferred: StringName, fallback: StringName) -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return
	if animated_sprite.sprite_frames.has_animation(preferred):
		if animated_sprite.animation != preferred or not animated_sprite.is_playing():
			animated_sprite.play(preferred)
		return
	if animated_sprite.sprite_frames.has_animation(fallback):
		if animated_sprite.animation != fallback or not animated_sprite.is_playing():
			animated_sprite.play(fallback)

func _build_default_animations() -> void:
	if animated_sprite == null:
		push_warning("AnimatedSprite2D not found. Animation playback is disabled.")
		return

	if animated_sprite.sprite_frames == null:
		animated_sprite.sprite_frames = SpriteFrames.new()

	var frames := animated_sprite.sprite_frames
	_add_strip_animation(frames, ANIM_IDLE_DOWN, "palyer_Idle_D.png", 8.0, true)
	_add_strip_animation(frames, ANIM_IDLE_UP, "player_Idle_U.png", 8.0, true)
	_add_strip_animation(frames, ANIM_IDLE_LEFT, "player_Idle_L.png", 8.0, true)
	_add_strip_animation(frames, ANIM_IDLE_RIGHT, "player_Idle_R.png", 8.0, true)

	_add_strip_animation(frames, ANIM_WALK_DOWN, "palyer_walk_D.png", 12.0, true)
	_add_strip_animation(frames, ANIM_WALK_UP, "player_walk_U.png", 12.0, true)
	_add_strip_animation(frames, ANIM_WALK_LEFT, "player_Walk_L.png", 12.0, true)
	_add_strip_animation(frames, ANIM_WALK_RIGHT, "player_Walk_R.png", 12.0, true)

	_add_strip_animation(frames, ANIM_ATTACK_LEFT, "player_attack2_L.png", 14.0, false)
	if not frames.has_animation(ANIM_ATTACK_LEFT):
		_add_strip_animation(frames, ANIM_ATTACK_LEFT, "player_attack_L.png", 14.0, false)

	_add_strip_animation(frames, ANIM_ATTACK_RIGHT, "player_attack2_R.png", 14.0, false)
	if not frames.has_animation(ANIM_ATTACK_RIGHT):
		_add_strip_animation(frames, ANIM_ATTACK_RIGHT, "player_attack_R.png", 14.0, false)

func _add_strip_animation(frames: SpriteFrames, animation_name: StringName, file_name: String, fps: float, loop: bool) -> void:
	if frames.has_animation(animation_name):
		return
	var path := PLAYER_SPRITE_DIR + file_name
	if not ResourceLoader.exists(path):
		return
	var texture := load(path) as Texture2D
	if texture == null:
		return
	if texture.get_width() < frame_width or frame_width <= 0:
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

func _ensure_default_input_actions() -> void:
	_ensure_key_actions(INPUT_MOVE_UP, [KEY_W, KEY_UP])
	_ensure_key_actions(INPUT_MOVE_DOWN, [KEY_S, KEY_DOWN])
	_ensure_key_actions(INPUT_MOVE_LEFT, [KEY_A, KEY_LEFT])
	_ensure_key_actions(INPUT_MOVE_RIGHT, [KEY_D, KEY_RIGHT])
	_ensure_mouse_action(INPUT_ATTACK, MOUSE_BUTTON_LEFT)

func _ensure_key_actions(action: StringName, keycodes: Array[Key]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)

	for keycode in keycodes:
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		if not _has_same_key_event(action, keycode):
			InputMap.action_add_event(action, event)

func _ensure_mouse_action(action: StringName, button_index: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)

	if _has_same_mouse_event(action, button_index):
		return

	var event := InputEventMouseButton.new()
	event.button_index = button_index
	InputMap.action_add_event(action, event)

func _has_same_key_event(action: StringName, keycode: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == keycode:
			return true
	return false

func _has_same_mouse_event(action: StringName, button_index: MouseButton) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == button_index:
			return true
	return false
