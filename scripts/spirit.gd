extends CharacterBody2D
class_name Spirit

signal player_attacked()
signal spirit_contained()
signal spirit_sealed()

enum State {
	PATROL,
	INVESTIGATING,
	PURSUIT,
	CONTAINED,
	SEALED
}

@export var patrol_speed: float = 38.0
@export var pursuit_speed: float = 72.0
@export var detection_radius: float = 120.0
@export var attack_radius: float = 18.0

var current_state: State = State.PATROL
var target_player: Player = null
var current_patrol_point: Vector2 = Vector2.ZERO
var patrol_points: Array[Vector2] = []
var patrol_idx: int = 0
var patrol_wait_timer: float = 0.0

var investigate_pos: Vector2 = Vector2.ZERO
var investigate_timer: float = 0.0

var bobbing_time: float = 0.0
var attack_cooldown: float = 0.0
var active_trap_circle: Node2D = null

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var ghost_light: PointLight2D = $GhostLight
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	_setup_sprite_frames()
	add_to_group("spirit")
	_pick_initial_patrol()

func _setup_sprite_frames() -> void:
	if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation("idle"):
		return

	var frames = SpriteFrames.new()
	var texture = load("res://assets/characters/ghost/ghost_sheet.png") as Texture2D
	if not texture:
		push_error("Could not load ghost_sheet.png")
		return

	var anim_names = ["idle", "move", "pursuit", "contained"]
	for row in range(4):
		var anim_name = anim_names[row]
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, 6.0)
		frames.set_animation_loop(anim_name, true)
		
		for col in range(4):
			var atlas = AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(col * 32, row * 32, 32, 32)
			frames.add_frame(anim_name, atlas)
			
	animated_sprite.sprite_frames = frames
	animated_sprite.play("idle")

func setup_patrol_points(points: Array[Vector2], player_ref: Player) -> void:
	patrol_points = points
	target_player = player_ref
	if not patrol_points.is_empty():
		current_patrol_point = patrol_points[0]

func _pick_initial_patrol() -> void:
	if patrol_points.is_empty():
		current_patrol_point = global_position

func _physics_process(delta: float) -> void:
	bobbing_time += delta
	var bob_offset = sin(bobbing_time * 3.5) * 2.5
	animated_sprite.position.y = -16.0 + bob_offset

	if attack_cooldown > 0.0:
		attack_cooldown -= delta

	match current_state:
		State.PATROL:
			_process_patrol(delta)
		State.INVESTIGATING:
			_process_investigate(delta)
		State.PURSUIT:
			_process_pursuit(delta)
		State.CONTAINED:
			_process_contained(delta)
		State.SEALED:
			# Frozen / sealed in circle
			velocity = Vector2.ZERO
			move_and_slide()

func _process_patrol(delta: float) -> void:
	if _check_for_player_spot():
		return

	if patrol_wait_timer > 0.0:
		patrol_wait_timer -= delta
		velocity = Vector2.ZERO
		animated_sprite.play("idle")
		move_and_slide()
		return

	if patrol_points.is_empty():
		return

	var target = current_patrol_point
	var dist = global_position.distance_to(target)
	if dist < 12.0:
		patrol_wait_timer = randf_range(1.5, 3.0)
		patrol_idx = (patrol_idx + 1) % patrol_points.size()
		current_patrol_point = patrol_points[patrol_idx]
		animated_sprite.play("idle")
		return

	var dir = (target - global_position).normalized()
	velocity = dir * patrol_speed
	_update_facing(dir.x)
	animated_sprite.play("move")
	move_and_slide()

func _process_investigate(delta: float) -> void:
	if _check_for_player_spot():
		return

	investigate_timer -= delta
	if investigate_timer <= 0.0:
		current_state = State.PATROL
		return

	var dist = global_position.distance_to(investigate_pos)
	if dist > 15.0:
		var dir = (investigate_pos - global_position).normalized()
		velocity = dir * patrol_speed * 1.2
		_update_facing(dir.x)
		animated_sprite.play("move")
	else:
		velocity = Vector2.ZERO
		animated_sprite.play("idle")
	move_and_slide()

func _process_pursuit(delta: float) -> void:
	if not is_instance_valid(target_player):
		current_state = State.PATROL
		return

	var p_pos = target_player.global_position
	var dist = global_position.distance_to(p_pos)

	# If player escaped too far
	if dist > detection_radius * 1.8:
		investigate_pos = p_pos
		investigate_timer = 3.0
		current_state = State.INVESTIGATING
		return

	var dir = (p_pos - global_position).normalized()
	velocity = dir * pursuit_speed
	_update_facing(dir.x)
	animated_sprite.play("pursuit")
	move_and_slide()

	# Attack player if in contact and not already trapped
	if dist <= attack_radius and attack_cooldown <= 0.0:
		attack_cooldown = 1.2
		target_player.take_damage(25, global_position)
		player_attacked.emit()

func _process_contained(delta: float) -> void:
	animated_sprite.play("contained")
	if is_instance_valid(active_trap_circle):
		# Struggle against edges
		var c_pos = active_trap_circle.global_position
		var jitter = Vector2(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0))
		global_position = global_position.move_toward(c_pos + jitter, 25.0 * delta)
		ghost_light.energy = 1.5 + 0.5 * sin(Time.get_ticks_msec() * 0.015)
	else:
		# If circle vanished without sealing (tether snap)
		break_free()

func _check_for_player_spot() -> bool:
	if not is_instance_valid(target_player):
		return false
	var dist = global_position.distance_to(target_player.global_position)
	if dist <= detection_radius:
		_enter_pursuit()
		return true
	return false

func _enter_pursuit() -> void:
	if current_state != State.PURSUIT:
		current_state = State.PURSUIT
		if SfxManager:
			SfxManager.play_ghost_spot()

func alert_to_disturbance(pos: Vector2) -> void:
	if current_state == State.PATROL:
		investigate_pos = pos
		investigate_timer = 5.0
		current_state = State.INVESTIGATING

func trap_in_ritual(circle: Node2D) -> void:
	current_state = State.CONTAINED
	active_trap_circle = circle
	velocity = Vector2.ZERO
	spirit_contained.emit()

func break_free() -> void:
	active_trap_circle = null
	current_state = State.PURSUIT
	# Enraged speed boost
	pursuit_speed = 88.0
	if SfxManager:
		SfxManager.play_ghost_spot()

func seal_permanently() -> void:
	current_state = State.SEALED
	active_trap_circle = null
	animated_sprite.play("contained")
	ghost_light.color = Color(0.3, 0.9, 1.0, 0.8)
	ghost_light.energy = 0.8
	spirit_sealed.emit()

func _update_facing(dir_x: float) -> void:
	if abs(dir_x) > 0.05:
		animated_sprite.flip_h = dir_x < 0.0
