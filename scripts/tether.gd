extends Node2D
class_name Tether

signal stability_changed(current_pct: float, state: String)
signal tether_snapped(midpoint: Vector2)

enum TetherState {
	STABLE,
	STRAINED,
	CRITICAL,
	SNAPPED
}

const MAX_SAFE_DISTANCE: float = 80.0
const BREAK_DISTANCE: float = 165.0

var source_node: Node2D = null
var target_node: Node2D = null
var is_active: bool = false

var stability: float = 100.0
var current_state: TetherState = TetherState.STABLE

# Textures
var tex_stable: Texture2D
var tex_strained: Texture2D
var tex_snapped: Texture2D

var anim_timer: float = 0.0
var frame_index: int = 0
var warning_sound_timer: float = 0.0

# Snapped animation state
var is_playing_snap_anim: bool = false
var snap_pos: Vector2 = Vector2.ZERO
var snap_rot: float = 0.0
var snap_frame: int = 0
var snap_timer: float = 0.0

func _ready() -> void:
	tex_stable = load("res://assets/ritual/tether_stable.png")
	tex_strained = load("res://assets/ritual/tether_strained.png")
	tex_snapped = load("res://assets/ritual/tether_snapped.png")
	z_index = 2

func bind(source: Node2D, target: Node2D) -> void:
	source_node = source
	target_node = target
	stability = 100.0
	current_state = TetherState.STABLE
	is_active = true
	is_playing_snap_anim = false
	visible = true
	stability_changed.emit(100.0, "stable")

func unbind() -> void:
	is_active = false
	visible = false

func _process(delta: float) -> void:
	if is_playing_snap_anim:
		snap_timer += delta
		if snap_timer >= 1.0 / 12.0:
			snap_timer = 0.0
			snap_frame += 1
			if snap_frame >= 4:
				is_playing_snap_anim = false
				visible = false
		queue_redraw()
		return

	if not is_active or not is_instance_valid(source_node) or not is_instance_valid(target_node):
		return

	var p1 = source_node.global_position
	var p2 = target_node.global_position
	var dist = p1.distance_to(p2)

	# Calculate stability based on distance
	if dist <= MAX_SAFE_DISTANCE:
		stability = 100.0
	else:
		var over = dist - MAX_SAFE_DISTANCE
		var max_over = BREAK_DISTANCE - MAX_SAFE_DISTANCE
		var ratio = clampf(over / max_over, 0.0, 1.0)
		stability = (1.0 - ratio) * 100.0

	var new_state: TetherState = TetherState.STABLE
	var state_str = "stable"
	if stability > 50.0:
		new_state = TetherState.STABLE
		state_str = "stable"
	elif stability > 25.0:
		new_state = TetherState.STRAINED
		state_str = "strained"
	elif stability > 0.0:
		new_state = TetherState.CRITICAL
		state_str = "critical"
	else:
		new_state = TetherState.SNAPPED
		state_str = "snapped"

	if current_state != new_state:
		current_state = new_state
		if current_state == TetherState.CRITICAL:
			if SfxManager:
				SfxManager.play_warning()

	if current_state == TetherState.CRITICAL:
		warning_sound_timer += delta
		if warning_sound_timer >= 0.4:
			warning_sound_timer = 0.0
			if SfxManager:
				SfxManager.play_warning()

	stability_changed.emit(stability, state_str)

	if dist >= BREAK_DISTANCE or stability <= 0.0:
		_trigger_snap(p1, p2)
		return

	# Animation timing
	anim_timer += delta
	var fps = 14.0 if current_state == TetherState.STRAINED or current_state == TetherState.CRITICAL else 10.0
	if anim_timer >= 1.0 / fps:
		anim_timer = 0.0
		frame_index = (frame_index + 1) % 4

	queue_redraw()

func _trigger_snap(p1: Vector2, p2: Vector2) -> void:
	is_active = false
	current_state = TetherState.SNAPPED
	stability = 0.0
	stability_changed.emit(0.0, "snapped")

	snap_pos = (p1 + p2) * 0.5
	snap_rot = (p2 - p1).angle()
	is_playing_snap_anim = true
	snap_frame = 0
	snap_timer = 0.0

	tether_snapped.emit(snap_pos)
	queue_redraw()

func _draw() -> void:
	if is_playing_snap_anim and tex_snapped:
		# Draw snapped animation at midpoint
		var local_snap = to_local(snap_pos)
		draw_set_transform(local_snap, snap_rot, Vector2.ONE)
		var src_rect = Rect2(snap_frame * 32, 0, 32, 16)
		draw_texture_rect_region(tex_snapped, Rect2(-16, -8, 32, 16), src_rect)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return

	if not is_active or not is_instance_valid(source_node) or not is_instance_valid(target_node):
		return

	var p1 = to_local(source_node.global_position)
	var p2 = to_local(target_node.global_position)
	var diff = p2 - p1
	var dist = diff.length()
	if dist < 4.0:
		return

	var angle = diff.angle()
	var texture_to_use = tex_stable
	if current_state == TetherState.STRAINED or current_state == TetherState.CRITICAL:
		texture_to_use = tex_strained

	if not texture_to_use:
		draw_line(p1, p2, Color.AQUA, 2.0)
		return

	var segment_w = 16.0
	var segment_h = 8.0
	var count = int(ceil(dist / segment_w))
	var src_rect = Rect2(frame_index * 16, 0, 16, 8)

	var draw_color = Color.WHITE
	if current_state == TetherState.CRITICAL:
		# Flash between amber and red
		draw_color = Color(1.2, 0.3, 0.3, 1.0) if int(Time.get_ticks_msec() / 80) % 2 == 0 else Color(1.0, 0.8, 0.2, 1.0)

	draw_set_transform(p1, angle, Vector2.ONE)

	var jitter_y: float = 0.0
	if current_state == TetherState.STRAINED:
		jitter_y = randf_range(-1.0, 1.0)
	elif current_state == TetherState.CRITICAL:
		jitter_y = randf_range(-2.5, 2.5)

	for i in range(count):
		var x_pos = i * segment_w
		var cur_w = segment_w
		if x_pos + cur_w > dist:
			cur_w = dist - x_pos
		var cur_src = Rect2(frame_index * 16, 0, cur_w, 8)
		var dest = Rect2(x_pos, -segment_h * 0.5 + jitter_y, cur_w, segment_h)
		draw_texture_rect_region(texture_to_use, dest, cur_src, draw_color)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
