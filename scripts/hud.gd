extends CanvasLayer
class_name HUD

signal restart_pressed()

@onready var objective_label: Label = $ObjectivePanel/ObjectiveLabel
@onready var stability_container: Control = $StabilityBar
@onready var stability_fill: TextureRect = $StabilityBar/StabilityFill
@onready var stability_text: Label = $StabilityBar/StabilityText
@onready var grimoire_dialog: PanelContainer = $GrimoireDialog
@onready var win_panel: PanelContainer = $WinPanel
@onready var game_over_panel: PanelContainer = $GameOverPanel
@onready var ritual_mode_indicator: Label = $BottomBar/RitualModeIndicator
@onready var health_label: Label = $TopLeft/HealthLabel
@onready var stun_indicator: Label = $StunIndicator

var tex_fill_stable: Texture2D
var tex_fill_strained: Texture2D
var tex_fill_critical: Texture2D

var is_grimoire_open: bool = false

func _ready() -> void:
	tex_fill_stable = load("res://assets/ui/stability_fill_stable.png")
	tex_fill_strained = load("res://assets/ui/stability_fill_strained.png")
	tex_fill_critical = load("res://assets/ui/stability_fill_critical.png")
	
	stability_container.visible = false
	grimoire_dialog.visible = false
	win_panel.visible = false
	game_over_panel.visible = false
	stun_indicator.visible = false
	
	set_objective("Search the village for a ritual site. Press SPACE or TAB for Grimoire.")

func set_objective(text: String) -> void:
	objective_label.text = text

func update_stability(pct: float, state: String) -> void:
	stability_container.visible = true
	var fill_width = clampf((pct / 100.0) * 60.0, 0.0, 60.0)
	stability_fill.size.x = fill_width
	
	if pct > 50.0:
		stability_fill.texture = tex_fill_stable
		stability_text.text = "TETHER: STABLE (%d%%)" % int(pct)
		stability_text.modulate = Color(0.4, 1.0, 0.8)
	elif pct > 25.0:
		stability_fill.texture = tex_fill_strained
		stability_text.text = "TETHER: STRAINED (%d%%)" % int(pct)
		stability_text.modulate = Color(1.0, 0.75, 0.2)
	elif pct > 0.0:
		stability_fill.texture = tex_fill_critical
		stability_text.text = "TETHER: CRITICAL! (%d%%)" % int(pct)
		stability_text.modulate = Color(1.0, 0.3, 0.3)
	else:
		stability_fill.texture = tex_fill_critical
		stability_text.text = "TETHER SNAPPED!"
		stability_text.modulate = Color(1.0, 0.1, 0.1)

func hide_stability() -> void:
	stability_container.visible = false

func update_health(hp: int) -> void:
	health_label.text = "Sanity: %d%%" % hp
	if hp <= 30:
		health_label.modulate = Color(1.0, 0.3, 0.3)
	else:
		health_label.modulate = Color(0.9, 0.9, 0.9)

func set_ritual_mode(enabled: bool) -> void:
	if enabled:
		ritual_mode_indicator.text = "[SPACE] CHALK DRAWING MODE: Click & drag mouse to trace circle"
		ritual_mode_indicator.modulate = Color(0.4, 0.9, 1.0)
	else:
		ritual_mode_indicator.text = "[SPACE] Ritual Mode | [F] Place Nail | [E] Interact | [TAB] Grimoire"
		ritual_mode_indicator.modulate = Color(0.7, 0.7, 0.7)

func set_stunned(stunned: bool) -> void:
	stun_indicator.visible = stunned

func toggle_grimoire() -> void:
	is_grimoire_open = !is_grimoire_open
	grimoire_dialog.visible = is_grimoire_open

func show_win_screen() -> void:
	win_panel.visible = true
	hide_stability()

func show_game_over_screen() -> void:
	game_over_panel.visible = true
	hide_stability()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_focus_next"): # Tab
		toggle_grimoire()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("restart_game"):
		if win_panel.visible or game_over_panel.visible:
			restart_pressed.emit()
