# Stamina HUD
# Displays the player's stamina bar in the top-left corner of the screen.
# Attach to a CanvasLayer that is a child of the Player node.
extends CanvasLayer

@onready var bar: ProgressBar = $Control/StaminaBar

func _ready() -> void:
	# Hide HUD for non-authority replicas (other players' stamina is not shown)
	visible = get_parent().is_multiplayer_authority()
	# Listen for stamina changes from the Stamina component
	var stamina = get_parent().get_node("Stamina(Node)")
	if stamina:
		stamina.stamina_changed.connect(_on_stamina_changed)
		# Set initial values
		bar.max_value = stamina.max_stamina
		bar.value = stamina.current_stamina

func _on_stamina_changed(current: float, max_val: float) -> void:
	bar.value = current
