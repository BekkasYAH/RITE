extends Node2D
class_name GameManager

@export var village_scene: PackedScene = preload("res://scenes/world/village.tscn")
@export var player_scene: PackedScene = preload("res://scenes/player/player.tscn")
@export var spirit_scene: PackedScene = preload("res://scenes/spirit/spirit.tscn")
@export var hud_scene: PackedScene = preload("res://scenes/ui/hud.tscn")

var village: Node2D = null
var player: Player = null
var spirit: Spirit = null
var ritual_manager: RitualManager = null
var hud: HUD = null

var is_game_over: bool = false
var is_game_won: bool = false

func _ready() -> void:
	get_viewport().canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_initialize_game()

func _initialize_game() -> void:
	if SfxManager.instance == null:
		var sfx = SfxManager.new()
		add_child(sfx)

	# 1. Spawn Village
	village = village_scene.instantiate()
	add_child(village)

	# 2. Spawn Player at SpawnPoint
	var spawn_pos = Vector2(110, 296)
	var spawn_node = village.get_node_or_null("SpawnPoint")
	if spawn_node:
		spawn_pos = spawn_node.global_position
		
	player = player_scene.instantiate() as Player
	player.global_position = spawn_pos
	village.get_node("Entities").add_child(player)

	# 3. Spawn Spirit at Graveyard
	var spirit_spawn = Vector2(520, 430)
	var patrol_pts: Array[Vector2] = []
	var patrol_node = village.get_node_or_null("PatrolPoints")
	if patrol_node:
		for child in patrol_node.get_children():
			patrol_pts.append(child.global_position)
		if not patrol_pts.is_empty():
			spirit_spawn = patrol_pts[0]
			
	spirit = spirit_scene.instantiate() as Spirit
	spirit.global_position = spirit_spawn
	village.get_node("Entities").add_child(spirit)
	spirit.setup_patrol_points(patrol_pts, player)

	# 4. Ritual Manager
	ritual_manager = RitualManager.new()
	add_child(ritual_manager)
	ritual_manager.setup(player)

	# 5. Spawn HUD
	hud = hud_scene.instantiate() as HUD
	add_child(hud)

	_connect_signals()

func _connect_signals() -> void:
	hud.restart_pressed.connect(_on_restart_pressed)
	
	player.ritual_mode_toggled.connect(func(active: bool):
		hud.set_ritual_mode(active)
		if active:
			hud.set_objective("Ritual Mode: Click & Drag with mouse to draw a containment circle.")
		else:
			hud.set_objective("Search village grounds. Press SPACE to prepare a ritual.")
	)
	
	ritual_manager.circle_placed.connect(_on_circle_placed)
	ritual_manager.circle_failed.connect(_on_circle_failed)
	ritual_manager.tether_node.stability_changed.connect(_on_stability_changed)
	ritual_manager.tether_node.tether_snapped.connect(_on_tether_snapped)

	spirit.player_attacked.connect(_on_player_attacked)

func _process(_delta: float) -> void:
	if is_game_over or is_game_won:
		return

	if is_instance_valid(player):
		hud.update_health(player.health)
		hud.set_stunned(player.is_stunned)
		if player.health <= 0:
			_trigger_game_over()

func _on_circle_placed(circle: RitualCircle) -> void:
	hud.set_objective("Containment circle drawn! Stand close and press F to drive the Iron Nail.")
	circle.ritual_anchored.connect(_on_ritual_anchored)
	circle.spirit_trapped.connect(_on_spirit_trapped)
	circle.spirit_sealed.connect(_on_spirit_sealed)
	circle.ritual_destroyed.connect(_on_ritual_destroyed)
	
	# Alert spirit to investigate disturbance
	if is_instance_valid(spirit):
		spirit.alert_to_disturbance(circle.global_position)

func _on_circle_failed(reason: String) -> void:
	hud.set_objective("Ritual failed: " + reason + " Try drawing a smooth closed loop.")

func _on_ritual_anchored(_anchor: Node2D) -> void:
	hud.set_objective("Ritual anchored! Ethereal tether established. Lure the spirit into the circle!")
	if is_instance_valid(spirit) and is_instance_valid(player):
		# Alert spirit into pursuit mode
		spirit.alert_to_disturbance(player.global_position)

func _on_stability_changed(pct: float, state: String) -> void:
	hud.update_stability(pct, state)

func _on_tether_snapped(_snap_pos: Vector2) -> void:
	hud.set_objective("TETHER BROKE! Shockwave stunned you! The spirit is enraged!")
	hud.hide_stability()
	if is_instance_valid(spirit):
		spirit.break_free()

func _on_ritual_destroyed() -> void:
	hud.hide_stability()

func _on_spirit_trapped(s: Node2D) -> void:
	if s == spirit:
		spirit.trap_in_ritual(ritual_manager.active_circle)
		hud.set_objective("SPIRIT TRAPPED IN CIRCLE! Maintain tether stability while runes converge!")

func _on_spirit_sealed(s: Node2D) -> void:
	if s == spirit:
		spirit.seal_permanently()
		_trigger_win()

func _on_player_attacked() -> void:
	if is_instance_valid(player):
		hud.update_health(player.health)
		if player.health <= 0:
			_trigger_game_over()

func _trigger_win() -> void:
	is_game_won = true
	hud.set_objective("CONVERGENCE COMPLETE. The village evil is contained forever.")
	hud.show_win_screen()

func _trigger_game_over() -> void:
	is_game_over = true
	hud.show_game_over_screen()

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()
