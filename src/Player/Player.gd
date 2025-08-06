extends KinematicBody2D  # <--- cambia de Node2D a KinematicBody2D

const Punch = preload("res://src/Attacks/Punch.tscn")
const Kick = preload("res://src/Attacks/Kick.tscn")

onready var original_position = position
onready var collision_shape = $CollisionShape2D
onready var hurtbox_shape = $HurtboxArea
onready var hitstun_timer = $HitstunTimer
onready var blockstun_timer = $BlockstunTimer
onready var slide_timer = $SlideTimer
onready var main = get_tree().get_root().get_node("Main")
onready var player_path = self.get_path()

onready var idle_animation = $IdleAnimation
onready var punch_animation = $PunchAnimation
onready var kick_animation = $KickAnimation
onready var move_animation = $MoveAnimation
onready var move_back_animation = $MoveBackAnimation
onready var hit_animation = $HitAnimation
onready var death_animation = $DeathAnimation

signal game_lost()
signal update_shield()

var input_prefix := "player1_"
var speed := 8
var is_lock = false
var is_lock_kick = false
var is_cancelable = false
var is_hitstun = false
var is_blockstun = false
var is_blocking = false
var shield_count = 3

var sliding = false

func _ready() -> void:
	SyncManager.connect("scene_spawned", self, "_on_SyncManager_scene_spawned")
	SyncManager.connect("scene_despawned", self, "_on_SyncManager_scene_despawned")
	set_facing_left()
	idle_animation.play("IdleAnimation")
	move_animation.play("MoveAnimation")
	move_back_animation.play("MoveBackAnimation")
	
func _get_local_input() -> Dictionary:
	var input_vector = Input.get_vector(input_prefix + "left", input_prefix + "right", "ui_up", "ui_down")
	var input := {}
	
	if input_vector != Vector2.ZERO:
		input["input_vector"] = input_vector

	if Input.is_action_just_pressed(input_prefix + "attack"):
		input["attack"] = true
	
	return input
	
func _predict_remote_input(previous_input: Dictionary, ticks_since_real_input: int) -> Dictionary:
	var input = previous_input.duplicate()
	input.erase("attack")
	return input

func _network_process(input: Dictionary) -> void:
	
		var motion = input.get("input_vector", Vector2.ZERO).normalized() * speed
		
		if player_path == "/root/Main/HostPlayer" && input.get("input_vector") == Vector2.LEFT:
			is_blocking = true
		elif player_path == "/root/Main/ClientPlayer" && input.get("input_vector") == Vector2.RIGHT:
			is_blocking = true
		else:
			is_blocking = false
		
		if input.get("attack", false) && not is_lock && not is_lock_kick && not is_hitstun && not is_blockstun:
			SyncManager.spawn("Punch", get_parent(), Punch, { position = global_position, player = self})
			
		if input.get("attack", false) && is_cancelable:
			slide()
			SyncManager.spawn("Kick", get_parent(), Kick, {position = global_position, player = self})
			
		if not _will_collide(motion) && not is_lock && not is_lock_kick && not is_hitstun && not is_blockstun:
			if motion != Vector2(0,0):
				if motion == Vector2(-speed,0) && player_path == "/root/Main/HostPlayer":
					$MoveBackSprites.visible = true
					$MoveSprites.visible = false
				elif motion == Vector2(speed,0) && player_path != "/root/Main/HostPlayer":
					$MoveBackSprites.visible = true
					$MoveSprites.visible = false
				else:
					$MoveSprites.visible = true
					$MoveBackSprites.visible = false
				$IdleSprites.visible = false
			else:
				$MoveSprites.visible = false
				$MoveBackSprites.visible = false
				$IdleSprites.visible = true
			position += motion

		if sliding:
			if player_path == "/root/Main/HostPlayer":
				position += Vector2(1,0) * speed
			else:
				position += Vector2(-1,0) * speed

func _will_collide(motion: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var shape = collision_shape.shape

	var params = Physics2DShapeQueryParameters.new()
	params.set_shape(shape)
	params.set_transform(Transform2D(0, global_position + motion))
	params.set_margin(15)
	params.exclude = [self]

	var result = space_state.intersect_shape(params, 1)
	return result.size() > 0

func _on_SyncManager_scene_spawned(name, spawned_node, scene, data) -> void:
	
	if name == 'Punch' and data['player_path'] == self.get_path():
		is_lock = true
		$IdleSprites.visible = false
		$MoveSprites.visible = false
		$MoveBackSprites.visible = false
		$PunchSprites.visible = true
		punch_animation.play("PunchAnimation")
	
	if name == 'Kick' and data['player_path'] == self.get_path():
		is_lock_kick = true
		is_cancelable = false
		$PunchSprites.visible = false
		$KickSprites.visible = true
		$IdleSprites.visible = false
		kick_animation.play("KickAnimation")

func _on_SyncManager_scene_despawned(name, despawned_node) -> void:
	
	if name == 'Punch':
		var player_path = despawned_node.player_path
		var player_node = get_node(player_path)
		if player_node == self:
			is_lock = false
			is_cancelable = false
			if not is_lock_kick:
				$IdleSprites.visible = true
			$PunchSprites.visible = false
	
	if name == 'PunchHitbox':
		var player_path = despawned_node.player_path
		var player_node = get_node(player_path)
		if player_node == self:
			is_cancelable = true
	
	if name == 'Kick':
		var player_path = despawned_node.player_path
		var player_node = get_node(player_path)
		if player_node == self:
			is_lock_kick = false
			$KickSprites.visible = false
			$IdleSprites.visible = true

func _save_state() -> Dictionary:
	return { "position": position,
		"is_lock": is_lock,
		"is_lock_kick": is_lock_kick,
		"is_cancelable": is_cancelable,
		"is_blocking": is_blocking,
		"is_hitstun": is_hitstun,
		"is_blockstun": is_blockstun,
		"shield_count": shield_count
		}

func _load_state(state: Dictionary) -> void:
	position = state["position"]
	is_lock = state["is_lock"]
	is_lock_kick = state["is_lock_kick"]
	is_cancelable = state["is_cancelable"]
	is_blocking = state["is_blocking"]
	is_hitstun = state["is_hitstun"]
	is_blockstun = state["is_blockstun"]
	shield_count = state["shield_count"]

func manage_hit(object_path: NodePath, killing_blow: bool):
	
	print(object_path, " ha golpeado a ", player_path)
	if is_blocking == true && shield_count >= 0:
		print("ATAQUE BLOQUEADO")
		if killing_blow:
			modify_shield(1)
		else:
			modify_shield(-1)
		is_blockstun = true
		blockstun_timer.start()
		$MoveSprites.visible = false
		$MoveBackSprites.visible = false
		$IdleSprites.visible = true
	else:
		$HitSprites.visible = true
		$IdleSprites.visible = false
		hit_animation.play("HitAnimation")
		if killing_blow:
			$IdleSprites.visible = false
			$HitSprites.visible = false
			$DeathSprites.visible = true
			death_animation.play("DeathAnimation")
			print("PARTIDA FINALIZADA:= ", player_path)
			emit_signal("game_lost")
		is_hitstun = true
		hitstun_timer.start()
	
func _on_HitstunTimer_timeout():
	is_hitstun = false
	$HitSprites.visible = false
	if not $DeathSprites.visible:
		$IdleSprites.visible = true

func _on_BlockstunTimer_timeout():
	is_blockstun = false
	print("YA NO ESTOY EN BLOCKSTUN")

func reset():
	$IdleSprites.visible = true
	$DeathSprites.visible = false
	position = original_position
	is_lock = false
	shield_count = 3
	emit_signal("update_shield")

func modify_shield(value: int):
	shield_count += value
	emit_signal("update_shield")

func slide():
	sliding = true
	slide_timer.start()

func _on_SlideTimer_timeout():
	sliding = false
	
func set_facing_left():
	if player_path != "/root/Main/HostPlayer":
		$IdleSprites.scale.x = -$IdleSprites.scale.x
		$PunchSprites.scale.x = -$PunchSprites.scale.x
		$KickSprites.scale.x = -$KickSprites.scale.x
		$MoveSprites.scale.x = -$MoveSprites.scale.x
		$MoveBackSprites.scale.x = -$MoveBackSprites.scale.x
		$HitSprites.scale.x = -$HitSprites.scale.x
		$DeathSprites.scale.x = -$DeathSprites.scale.x
