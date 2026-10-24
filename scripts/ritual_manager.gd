extends Node2D
class_name RitualManager

signal circle_placed(circle: RitualCircle)
signal circle_failed(reason: String)

@export var circle_scene: PackedScene = preload("res://scenes/ritual/ritual_circle.tscn")
@export var max_drawing_distance_from_player: float = 90.0

var player: Player = null
var active_circle: RitualCircle = null
var tether_node: Tether = null

var is_drawing: bool = false
var drawn_points: Array[Vector2] = []
var chalk_audio_timer: float = 0.0

# Visual feedback for invalid drawing
var invalid_fade_timer: float = 0.0
var invalid_points: Array[Vector2] = []
var is_showing_invalid: bool = false

func _ready() -> void:
	z_index = 3
	tether_node = Tether.new()
	add_child(tether_node)
	tether_node.tether_snapped.connect(_on_tether_snapped)

func setup(p: Player) -> void:
	player = p
	player.ritual_mode_toggled.connect(_on_ritual_mode_toggled)
	player.nail_place_requested.connect(_on_nail_place_requested)
	player.interaction_requested.connect(_on_interaction_requested)

func _on_ritual_mode_toggled(active: bool) -> void:
	if not active and is_drawing:
		_finish_drawing()
	queue_redraw()

func _on_interaction_requested() -> void:
	_try_anchor_circle()

func _on_nail_place_requested() -> void:
	_try_anchor_circle()

func _try_anchor_circle() -> void:
	if not is_instance_valid(player) or not is_instance_valid(active_circle):
		return
	
	if active_circle.current_state == RitualCircle.State.UNANCHORED:
		var dist = player.global_position.distance_to(active_circle.global_position)
		if dist <= 55.0:
			if active_circle.anchor_ritual():
				# Bind tether between circle anchor and player
				tether_node.bind(active_circle.anchor_point, player)

func _on_tether_snapped(midpoint: Vector2) -> void:
	if is_instance_valid(player):
		player.apply_shockwave_stun(midpoint)
	if is_instance_valid(active_circle):
		active_circle.collapse_ritual()
		active_circle = null

func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(player) or not player.is_drawing_mode or player.is_stunned:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_drawing()
		else:
			_finish_drawing()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and is_drawing:
		_add_drawing_point(get_global_mouse_position())
		get_viewport().set_input_as_handled()

func _start_drawing() -> void:
	is_drawing = true
	drawn_points.clear()
	is_showing_invalid = false
	var mpos = get_global_mouse_position()
	_add_drawing_point(mpos)

func _add_drawing_point(mpos: Vector2) -> void:
	# Ensure drawing is within player range
	if player and mpos.distance_to(player.global_position) > max_drawing_distance_from_player:
		# Clamp to max range
		mpos = player.global_position + (mpos - player.global_position).normalized() * max_drawing_distance_from_player

	if drawn_points.is_empty():
		drawn_points.append(mpos)
		if SfxManager:
			SfxManager.play_chalk()
		queue_redraw()
		return

	var last_pt = drawn_points[-1]
	if last_pt.distance_to(mpos) >= 5.0:
		drawn_points.append(mpos)
		chalk_audio_timer += 0.05
		if chalk_audio_timer >= 0.12:
			chalk_audio_timer = 0.0
			if SfxManager:
				SfxManager.play_chalk()
		queue_redraw()

func _finish_drawing() -> void:
	if not is_drawing:
		return
	is_drawing = false
	
	if drawn_points.size() < 12:
		_reject_drawing("Too short. Draw a complete circular containment seal.")
		return
		
	var validation = _validate_circle(drawn_points)
	if validation.valid:
		_accept_circle(validation.center)
	else:
		_reject_drawing(validation.reason)
		
	drawn_points.clear()
	queue_redraw()

func _validate_circle(points: Array[Vector2]) -> Dictionary:
	var count = points.size()
	
	# 1. Total path length
	var total_length: float = 0.0
	for i in range(count - 1):
		total_length += points[i].distance_to(points[i + 1])
		
	# 2. Closure check (first point to last point)
	var closure_dist = points[0].distance_to(points[-1])
	if closure_dist > 45.0 and closure_dist > total_length * 0.35:
		return {"valid": false, "reason": "Circle must be closed.", "center": Vector2.ZERO}
		
	# 3. Calculate centroid
	var sum = Vector2.ZERO
	for pt in points:
		sum += pt
	var center = sum / float(count)
	
	# 4. Radii from center
	var radii: Array[float] = []
	var r_sum: float = 0.0
	for pt in points:
		var r = pt.distance_to(center)
		radii.append(r)
		r_sum += r
	var r_avg = r_sum / float(count)
	
	# 5. Radius limits (must be between 22 and 70 pixels)
	if r_avg < 22.0:
		return {"valid": false, "reason": "Circle too small.", "center": center}
	if r_avg > 70.0:
		return {"valid": false, "reason": "Circle too large for ritual seal.", "center": center}
		
	# 6. Variance / circularity check
	var variance_sum: float = 0.0
	for r in radii:
		variance_sum += pow(r - r_avg, 2.0)
	var std_dev = sqrt(variance_sum / float(count))
	var roundness_ratio = std_dev / r_avg
	
	# Reasonable tolerance for human mouse drawing: up to 0.38
	if roundness_ratio > 0.38:
		return {"valid": false, "reason": "Irregular shape: must be reasonably round.", "center": center}
		
	# 7. Angular span around center
	var total_angle: float = 0.0
	for i in range(count - 1):
		var v1 = (points[i] - center).normalized()
		var v2 = (points[i + 1] - center).normalized()
		var da = v1.angle_to(v2)
		total_angle += da
		
	if abs(total_angle) < (1.5 * PI): # At least ~270 degrees traversed
		return {"valid": false, "reason": "Incomplete loop: trace the full perimeter.", "center": center}
		
	return {"valid": true, "reason": "Valid circle.", "center": center}

func _accept_circle(center_pos: Vector2) -> void:
	# Destroy previous unanchored circle if any
	if is_instance_valid(active_circle):
		if active_circle.current_state == RitualCircle.State.UNANCHORED:
			active_circle.queue_free()
		elif active_circle.current_state == RitualCircle.State.ANCHORED:
			active_circle.collapse_ritual()
			
	var circle = circle_scene.instantiate() as RitualCircle
	circle.global_position = center_pos
	get_parent().add_child(circle)
	active_circle = circle
	
	if SfxManager:
		SfxManager.play_chalk()
		
	circle_placed.emit(circle)

func _reject_drawing(reason: String) -> void:
	invalid_points = drawn_points.duplicate()
	is_showing_invalid = true
	invalid_fade_timer = 0.65
	if SfxManager:
		SfxManager.play_warning()
	circle_failed.emit(reason)

func _process(delta: float) -> void:
	if is_showing_invalid:
		invalid_fade_timer -= delta
		if invalid_fade_timer <= 0.0:
			is_showing_invalid = false
			invalid_points.clear()
		queue_redraw()

func _draw() -> void:
	# Draw currently stroked points
	if is_drawing and drawn_points.size() > 1:
		for i in range(drawn_points.size() - 1):
			var p1 = to_local(drawn_points[i])
			var p2 = to_local(drawn_points[i + 1])
			draw_line(p1, p2, Color(0.95, 0.95, 1.0, 0.85), 2.5, true)
			draw_circle(p2, 1.5, Color(1.0, 1.0, 1.0, 0.9))

	# Draw failed invalid attempt fading out red
	if is_showing_invalid and invalid_points.size() > 1:
		var alpha = clampf(invalid_fade_timer / 0.65, 0.0, 1.0)
		var err_color = Color(0.9, 0.2, 0.2, alpha * 0.75)
		for i in range(invalid_points.size() - 1):
			var p1 = to_local(invalid_points[i])
			var p2 = to_local(invalid_points[i + 1])
			draw_line(p1, p2, err_color, 2.0, true)

	# If player is in drawing mode, draw subtle range preview indicator
	if is_instance_valid(player) and player.is_drawing_mode and not is_drawing:
		var mpos = to_local(get_global_mouse_position())
		draw_arc(mpos, 35.0, 0, TAU, 32, Color(0.6, 0.8, 1.0, 0.35), 1.0)
		draw_circle(mpos, 2.0, Color(0.8, 0.9, 1.0, 0.7))
