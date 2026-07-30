extends CharacterBody2D

@onready var hurtbox = $"HurtBox(Area2D)"
@onready var health = $"Health(Node)"

func _ready():
	hurtbox.hit_received.connect(_on_hit_received)
	health.died.connect(_on_died)

func _on_hit_received(hitbox):
	print("Enemy received an attack! From: ", hitbox.name)
	
	health.take_damage(hitbox.get_damage())

func _on_died():
	print("Enemy Died!")
