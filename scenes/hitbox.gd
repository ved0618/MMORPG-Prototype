extends Area2D
@onready var weapon = get_parent()

func get_damage() -> int:
	return weapon.damage

func _ready():
	monitoring = false
	monitorable = false
	area_entered.connect(_on_area_entered)

func enable_hitbox():
	monitoring = true
	monitorable = true
	print("Hitbox Enabled")

func disable_hitbox():
	monitoring = false
	monitorable = false
	print("Hitbox Disabled")

func _on_area_entered(area):
	print("Weapon hit:", area.name)
