extends CharacterBody2D

# ============================================================
# BOSS
# Server-authoritative multiplayer boss
# ============================================================

@onready var hurtbox = $"HurtBox(Area2D)"
@onready var health = $"Health(Node)"
@onready var animated_sprite = $AnimatedSprite2D

# -----------------------------
# BOSS STATS
# -----------------------------

@export var max_health: int = 500
@export var move_speed: float = 55.0
@export var alert_radius: float = 400.0
@export var attack_range: float = 28.0

@export var attack_damage: int = 25
@export var attack_cooldown: float = 1.5

# -----------------------------
# RUNTIME
# -----------------------------

var attack_timer: float = 0.0
var dead: bool = false


func _ready() -> void:

	# Boss health
	health.max_health = max_health
	health.current_health = max_health

	# Receive player attacks
	hurtbox.hit_received.connect(_on_hit_received)

	# Death
	health.died.connect(_on_died)

	print("BOSS READY: ", name)
	print("Boss HP: ", health.current_health)


func _physics_process(delta: float) -> void:

	# Only server controls boss AI
	if not multiplayer.is_server():
		return

	if dead:
		return

	attack_timer = maxf(attack_timer - delta, 0.0)

	var target := _nearest_player()

	if target == null:
		velocity = Vector2.ZERO
		return

	var distance := global_position.distance_to(target.global_position)

	# Player too far away
	if distance > alert_radius:
		velocity = Vector2.ZERO
		return

	var direction := target.global_position - global_position

	# -----------------------------
	# ATTACK
	# -----------------------------

	if distance <= attack_range:

		velocity = Vector2.ZERO

		if attack_timer <= 0.0:
			_attack(target)
			attack_timer = attack_cooldown

	# -----------------------------
	# CHASE
	# -----------------------------

	else:

		velocity = direction.normalized() * move_speed

		move_and_slide()

		_update_animation(direction)


# ============================================================
# FIND CLOSEST PLAYER
# ============================================================

func _nearest_player() -> Node2D:

	var nearest: Node2D = null
	var nearest_distance := alert_radius + 1.0

	for player in get_tree().get_nodes_in_group("players"):

		if not player.is_inside_tree():
			continue

		if not player.has_node("Health(Node)"):
			continue

		var distance := global_position.distance_to(player.global_position)

		if distance < nearest_distance:

			nearest = player
			nearest_distance = distance

	return nearest


# ============================================================
# BOSS ATTACK
# ============================================================

func _attack(player: Node2D) -> void:

	if player == null:
		return

	# Check the actual distance again before dealing damage.
	var distance: float = global_position.distance_to(player.global_position)

	if distance > attack_range:
		return

	# Player is invulnerable during teleport.
	if player.get("is_invulnerable") == true:
		return

	print("BOSS ATTACK -> ", player.name)
	print("Attack distance: ", distance)

	var player_health = player.get_node_or_null("Health(Node)")

	if player_health == null:
		return

	if player_health.has_method("take_damage"):
		player_health.take_damage(attack_damage)


# ============================================================
# BOSS ANIMATION
# ============================================================

func _update_animation(direction: Vector2) -> void:

	# This works with the current wolf-style animations
	# until we replace the sprite with the Orc.

	if direction.y >= 0.0:

		if animated_sprite.sprite_frames.has_animation("f_walk"):
			if animated_sprite.animation != &"f_walk":
				animated_sprite.play("f_walk")

	else:

		if animated_sprite.sprite_frames.has_animation("b_walk"):
			if animated_sprite.animation != &"b_walk":
				animated_sprite.play("b_walk")


# ============================================================
# PLAYER HIT BOSS
# ============================================================

func _on_hit_received(hitbox) -> void:

	print("BOSS WAS HIT!")

	# Only server handles damage
	if not multiplayer.is_server():
		return

	# Ignore non-damaging areas
	if not hitbox.has_method("get_damage"):
		return

	var damage: int = hitbox.get_damage()

	print("Boss Damage: ", damage)

	health.take_damage(damage)


# ============================================================
# BOSS DEATH
# ============================================================

func _on_died() -> void:

	if dead:
		return

	if not multiplayer.is_server():
		return

	dead = true

	velocity = Vector2.ZERO

	print("================================")
	print("BOSS DEFEATED!")
	print("================================")

	# For now remove boss immediately.
	# Later we will add death animation + Orb drop here.

	queue_free()
