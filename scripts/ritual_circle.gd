extends Node2D
class_name RitualCircle

signal ritual_anchored(anchor_node: Node2D)
signal ritual_snapped(pos: Vector2)
signal spirit_trapped(spirit: Node2D)
signal spirit_sealed(spirit: Node2D)
signal ritual_destroyed()

enum State {
	UNANCHORED,
	ANCHORED,
	CONTAINING,
	SEALED,
	COLLAPSED
}

var current_state: State = State.UNANCHORED
var trap_radius: float = 42.0
var trapped_spirit: Node2D = null

# Containment progress
var containment_timer: float = 0.0
const REQUIRED_CONTAIN_TIME: float = 5.0

# Animation timers
var active_anim_timer: float = 0.0
var active_frame: int = 0

var nail_anim_timer: float = 0.0
var nail_frame: int = 0

var seal_effect_playing: bool = false
var seal_effect_timer: float = 0.0
var seal_effect_frame: int = 0

# Textures
var tex_chalk: Texture2D
var tex_active: Texture2D
var tex_nail: Texture2D
var tex_seal_effect: Texture2D

@onready var chalk_sprite: Sprite2D = $ChalkSprite
@onready var active_sprite: Sprite2D = $ActiveSprite
@onready var nail_sprite: Sprite2D = $NailSprite
@onready var seal_effect_sprite: Sprite2D = $SealEffectSprite
@onready var trigger_area: Area2D = $TriggerArea
@onready var anchor_point: Marker2D = $AnchorPoint
@onready var rune_light: PointLight2D = $RuneLight

func _ready() -> void:
	tex_chalk = load("res://assets/ritual/containment_circle_chalk.png")
	tex_active = load("res://assets/ritual/containment_circle_active.png")
	tex_nail = load("res://assets/ritual/iron_nail.png")
	tex_seal_effect = load("res://assets/ritual/containment_effect.png")

	chalk_sprite.texture = tex_chalk
	active_sprite.visible = false
	nail_sprite.visible = false
	seal_effect_sprite.visible = false
	rune_light.enabled = false

	trigger_area.body_entered.connect(_on_body_entered)

func anchor_ritual() -> bool:
	if current_state != State.UNANCHORED:
		return false
	
	current_state = State.ANCHORED
	nail_sprite.visible = true
	active_sprite.visible = true
	rune_light.enabled = true
	
	if SfxManager:
		SfxManager.play_nail()
		SfxManager.play_activate()
		
	ritual_anchored.emit(anchor_point)
	return true

func _process(delta: float) -> void:
	if current_state == State.ANCHORED or current_state == State.CONTAINING:
		# Animate active ritual runes (4 frames @ 6 fps)
		active_anim_timer += delta
		if active_anim_timer >= 1.0 / 6.0:
			active_anim_timer = 0.0
			active_frame = (active_frame + 1) % 4
			active_sprite.region_rect = Rect2(active_frame * 96, 0, 96, 96)
			
		# Animate iron nail glow (frames 1..4 @ 6 fps)
		nail_anim_timer += delta
		if nail_anim_timer >= 1.0 / 6.0:
			nail_anim_timer = 0.0
			nail_frame = 1 + ((nail_frame) % 4)
			nail_sprite.region_rect = Rect2(nail_frame * 16, 0, 16, 16)
			
		# Light pulsation
		rune_light.energy = 0.8 + 0.3 * sin(Time.get_ticks_msec() * 0.005)

	if current_state == State.CONTAINING:
		if is_instance_valid(trapped_spirit):
			containment_timer += delta
			# Pull spirit to center
			trapped_spirit.global_position = trapped_spirit.global_position.move_toward(global_position, 60.0 * delta)
			
			if containment_timer >= REQUIRED_CONTAIN_TIME:
				_complete_sealing()
		else:
			current_state = State.ANCHORED
			containment_timer = 0.0

	if seal_effect_playing:
		seal_effect_timer += delta
		if seal_effect_timer >= 1.0 / 10.0:
			seal_effect_timer = 0.0
			seal_effect_frame += 1
			if seal_effect_frame < 8:
				seal_effect_sprite.region_rect = Rect2(seal_effect_frame * 96, 0, 96, 96)
			else:
				# Keep frame 7 (settled seal)
				seal_effect_sprite.region_rect = Rect2(7 * 96, 0, 96, 96)

func _complete_sealing() -> void:
	current_state = State.SEALED
	seal_effect_playing = true
	seal_effect_frame = 0
	seal_effect_sprite.visible = true
	seal_effect_sprite.region_rect = Rect2(0, 0, 96, 96)
	
	if SfxManager:
		SfxManager.play_seal_win()
		
	if is_instance_valid(trapped_spirit):
		spirit_sealed.emit(trapped_spirit)

func _on_body_entered(body: Node2D) -> void:
	if current_state == State.ANCHORED and body.is_in_group("spirit"):
		current_state = State.CONTAINING
		trapped_spirit = body
		containment_timer = 0.0
		if SfxManager:
			SfxManager.play_ghost_contain()
		spirit_trapped.emit(body)

func collapse_ritual() -> void:
	if current_state == State.SEALED:
		return
	current_state = State.COLLAPSED
	active_sprite.visible = false
	rune_light.enabled = false
	nail_sprite.modulate = Color(0.5, 0.5, 0.5, 0.5)
	chalk_sprite.modulate = Color(0.6, 0.3, 0.3, 0.6)
	
	ritual_destroyed.emit()
	
	# Fade out and destroy
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.2)
	tween.tween_callback(queue_free)
