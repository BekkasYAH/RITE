extends CharacterBody2D
class_name Player

signal interaction_requested()
signal ritual_mode_toggled(active: bool)
signal nail_place_requested()

const SPEED: float = 85.0
const STUN_DURATION: float = 2.5

@export var max_health: int = 100

var health: int = 100
var is_stunned: bool = false
var stun_timer: float = 0.0
var knockback_velocity: Vector2 = Vector2.ZERO
var facing_direction: Vector2 = Vector2.DOWN
var is_drawing_mode: bool = false
var has_nail: bool = true

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var lantern_light: PointLight2D = $LanternLight
@onready var interact_area: Area2D = $InteractArea
@onready var camera: Camera2D = $Camera2D

var shake_intensity: float = 0.0
var shake_decay: float = 5.0

func _ready() -> void:
	_setup_sprite_frames()
	health = max_health

func _setup_sprite_frames() -> void:
	if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation("idle_down"):
		return
	
	var frames = SpriteFrames.new()
	var texture = load("res://assets/characters/player/player_sheet.png") as Texture2D
	if not texture:
		push_error("Could not load player_sheet.png")
		return

	var directions = ["down", "left", "right", "up"]
	for row in range(4):
		var dir_name = directions[row]
		var idle_anim = "idle_" + dir_name
		var walk_anim = "walk_" + dir_name
		
		frames.add_animation(idle_anim)
		frames.set_animation_speed(idle_anim, 2.0)
		frames.set_animation_loop(idle_anim, true)
		
		frames.add_animation(walk_anim)
		frames.set_animation_speed(walk_anim, 8.0)
		frames.set_animation_loop(walk_anim, true)
		
		# idle0, idle1
		for col in range(2):
			var atlas = AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(col * 16, row * 24, 16, 24)
			frames.add_frame(idle_anim, atlas)
		
		# walk0, walk1, walk2, walk3
		for col in range(2, 6):
			var atlas = AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(col * 16, row * 24, 16, 24)
			frames.add_frame(walk_anim, atlas)
			
	animated_sprite.sprite_frames = frames
	animated_sprite.play("idle_down")

func _physics_process(delta: float) -> void:
	_process_screen_shake(delta)
	
	if is_stunned:
		stun_timer -= delta
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 300.0 * delta)
		move_and_slide()
		
		# Flashing effect
		var flash = int(stun_timer * 10.0) % 2 == 0
		animated_sprite.modulate = Color(1.0, 0.4, 0.4, 0.8) if flash else Color(1.0, 1.0, 1.0, 0.5)
		
		if stun_timer <= 0.0:
			is_stunned = false
			animated_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
		return

	var input_vec = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	
	if is_drawing_mode:
		# Player movement is slowed while drawing
		input_vec *= 0.35
		
	if input_vec.length_squared() > 1.0:
		input_vec = input_vec.normalized()
		
	velocity = input_vec * SPEED
	move_and_slide()
	
	_update_animation(input_vec)

func _process_screen_shake(delta: float) -> void:
	if shake_intensity > 0.0:
		camera.offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		shake_intensity = maxf(0.0, shake_intensity - shake_decay * delta)
	else:
		camera.offset = Vector2.ZERO

func apply_screen_shake(amount: float) -> void:
	shake_intensity = maxf(shake_intensity, amount)

func _update_animation(input_vec: Vector2) -> void:
	var state = "walk" if input_vec.length() > 0.1 else "idle"
	
	if input_vec.length() > 0.1:
		if abs(input_vec.x) > abs(input_vec.y):
			facing_direction = Vector2.RIGHT if input_vec.x > 0 else Vector2.LEFT
		else:
			facing_direction = Vector2.DOWN if input_vec.y > 0 else Vector2.UP
			
	var dir_str = "down"
	if facing_direction == Vector2.UP:
		dir_str = "up"
	elif facing_direction == Vector2.LEFT:
		dir_str = "left"
	elif facing_direction == Vector2.RIGHT:
		dir_str = "right"
		
	var anim_name = "%s_%s" % [state, dir_str]
	if animated_sprite.animation != anim_name:
		animated_sprite.play(anim_name)

func _unhandled_input(event: InputEvent) -> void:
	if is_stunned:
		return
		
	if event.is_action_pressed("toggle_ritual"):
		is_drawing_mode = !is_drawing_mode
		ritual_mode_toggled.emit(is_drawing_mode)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		interaction_requested.emit()
	elif event.is_action_pressed("place_nail"):
		nail_place_requested.emit()

func apply_shockwave_stun(from_pos: Vector2, knockback_force: float = 140.0) -> void:
	is_stunned = true
	stun_timer = STUN_DURATION
	var dir = (global_position - from_pos).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN
	knockback_velocity = dir * knockback_force
	apply_screen_shake(8.0)
	if SfxManager:
		SfxManager.play_snap()

func take_damage(amount: int, from_pos: Vector2) -> void:
	if is_stunned:
		return
	health -= amount
	apply_screen_shake(5.0)
	if SfxManager:
		SfxManager.play_player_hit()
	if health <= 0:
		health = 0
		# Signal game manager handled separately
