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
@export var attack_range: float = 72.0

@export var attack_damage: int = 25
@export var attack_cooldown: float = 1.5

# -----------------------------
# RUNTIME
# -----------------------------

var attack_timer: float = 0.0
var dead: bool = false
var attacking: bool = false
var hurt_animation_playing: bool = false
var facing_direction := "front"


func _ready() -> void:
	_configure_walk_animations()

	# Boss health
	health.max_health = max_health
	health.current_health = max_health

	# Receive player attacks
	hurtbox.hit_received.connect(_on_hit_received)

	# Death
	health.died.connect(_on_died)
	_play_directional_animation("idle", facing_direction)

	print("BOSS READY: ", name)
	print("Boss HP: ", health.current_health)


func _physics_process(delta: float) -> void:

	# Only server controls boss AI
	if not multiplayer.is_server():
		return

	if dead:
		return

	attack_timer = maxf(attack_timer - delta, 0.0)
	if attacking or hurt_animation_playing:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var target := _nearest_player()

	if target == null:
		velocity = Vector2.ZERO
		move_and_slide()
		_play_directional_animation("idle", facing_direction)
		return

	var distance := global_position.distance_to(target.global_position)

	# Player too far away
	if distance > alert_radius:
		velocity = Vector2.ZERO
		move_and_slide()
		_play_directional_animation("idle", facing_direction)
		return

	var direction := target.global_position - global_position

	# -----------------------------
	# ATTACK
	# -----------------------------

	if distance <= attack_range:

		velocity = Vector2.ZERO
		move_and_slide()
		_update_facing(direction)

		if attack_timer <= 0.0:
			_attack(target)
			attack_timer = attack_cooldown
		else:
			_play_directional_animation("idle", facing_direction)

	# -----------------------------
	# CHASE
	# -----------------------------

	else:

		_update_facing(direction)
		velocity = direction.normalized() * move_speed

		move_and_slide()

		_play_directional_animation("walk", facing_direction)


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

	var player_health = player.get_node_or_null("Health(Node)")

	if player_health == null:
		return

	_update_facing(player.global_position - global_position)
	attacking = true
	animated_sprite.play(_animation_name("attack", facing_direction))
	print("BOSS ATTACK -> ", player.name, " (distance: ", distance, ")")

	if player_health.has_method("take_damage"):
		player_health.take_damage(attack_damage)

	await animated_sprite.animation_finished
	attacking = false


# ============================================================
# BOSS ANIMATION
# ============================================================

func _update_facing(direction: Vector2) -> void:
	if absf(direction.x) > absf(direction.y):
		facing_direction = "side"
		animated_sprite.flip_h = direction.x < 0.0
	elif direction.y < 0.0:
		facing_direction = "back"
		animated_sprite.flip_h = false
	else:
		facing_direction = "front"
		animated_sprite.flip_h = false


func _animation_name(action: String, facing: String) -> String:
	return "%s_%s" % [action, facing]


func _play_directional_animation(action: String, facing: String) -> void:
	var animation_name := _animation_name(action, facing)
	if animated_sprite.sprite_frames.has_animation(animation_name) and animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)


func _configure_walk_animations() -> void:
	# The boss scene had walk animations with no frames, so populate them from
	# the Orc's four-row walk sheet at runtime.
	var walk_sheet := load("res://Assets/Sprites/Player/Free-Top-Down-Orc-Game-Character-Pixel-Art/PNG/Orc1/Orc1_walk/orc1_walk_full.png") as Texture2D
	if walk_sheet == null:
		push_warning("Boss walk sprite sheet could not be loaded.")
		return

	var frames: SpriteFrames = animated_sprite.sprite_frames
	var row_by_animation := {
		"walk_back": 0,
		"walk_front": 1,
		"walk_side": 2,
	}
	for animation_name in row_by_animation:
		if not frames.has_animation(animation_name):
			frames.add_animation(animation_name)
		if frames.get_frame_count(animation_name) > 0:
			continue
		for frame_index in range(6):
			var atlas := AtlasTexture.new()
			atlas.atlas = walk_sheet
			atlas.region = Rect2(frame_index * 64, int(row_by_animation[animation_name]) * 64, 64, 64)
			frames.add_frame(animation_name, atlas)
		frames.set_animation_speed(animation_name, 8.0)
		frames.set_animation_loop(animation_name, true)


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
	if not dead and not attacking:
		hurt_animation_playing = true
		animated_sprite.play(_animation_name("hurt", facing_direction))
		_finish_hurt_animation()


func _finish_hurt_animation() -> void:
	await animated_sprite.animation_finished
	hurt_animation_playing = false


# ============================================================
# BOSS DEATH
# ============================================================

func _on_died() -> void:

	if dead:
		return

	if not multiplayer.is_server():
		return

	dead = true
	attacking = false
	hurt_animation_playing = false

	velocity = Vector2.ZERO

	print("================================")
	print("BOSS DEFEATED!")
	print("================================")

	animated_sprite.play(_animation_name("death", facing_direction))
	await animated_sprite.animation_finished
	queue_free()
