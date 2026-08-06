# Hitbix
# Detects what this weapon hits

extends Area2D
@onready var weapon = get_parent()

# Returns the weapon's damage value
func get_damage() -> int:
	return weapon.damage

func _ready():
	# Disable the collision until the attack animation activates it
	monitoring = false
	monitorable = false
	area_entered.connect(_on_area_entered)

# Called during the active attack frames
func enable_hitbox():
	monitoring = true
	monitorable = true
	print("Hitbox Enabled")

# Prevents the weapon from dealing damage outside the attack
func disable_hitbox():
	monitoring = false
	monitorable = false
	print("Hitbox Disabled")

func _on_area_entered(area):
	print("Weapon hit:", area.name)
