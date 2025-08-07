extends KinematicBody2D  # <--- cambia de Node2D a KinematicBody2D

const BlowSound = preload("res://assets/sounds/body_hit_large_76.wav")
const KillingBlowSound = preload("res://assets/sounds/body_hit_finisher_52.wav")
const BlockSound = preload("res://assets/sounds/block_medium_25.wav")
const ThrowSound = preload("res://assets/sounds/punch_long_whoosh_30.wav")

onready var original_position = position
onready var player_pushbox = $PushBox
onready var hurtbox_shape = $HurtboxArea
onready var hitstun_timer = $Timers/HitstunTimer
onready var blockstun_timer = $Timers/BlockstunTimer

onready var punch_timer = $Punch/PunchTimer
onready var punch_startup_timer = $Punch/PunchStartupTimer
onready var kick_timer = $Kick/KickTimer
onready var kick_startup_timer = $Kick/KickStartupTimer

onready var main = get_tree().get_root().get_node("Main")
onready var player_path = self.get_path()

onready var idle_animation = $Animations/IdleAnimation
onready var punch_animation = $Animations/PunchAnimation
onready var kick_animation = $Animations/KickAnimation
onready var move_animation = $Animations/MoveAnimation
onready var move_back_animation = $Animations/MoveBackAnimation
onready var hit_animation = $Animations/HitAnimation
onready var death_animation = $Animations/DeathAnimation

signal game_lost()
signal update_shield()

var input_prefix := "player1_"
var speed := 4
var is_lock = false
var is_lock_kick = false
var is_cancelable = false
var is_hitstun = false
var is_blockstun = false
var is_blocking = false
var shield_count = 3
var is_game_over = false

func _ready() -> void:
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
	
	if not is_game_over:
	
		var motion = input.get("input_vector", Vector2.ZERO).normalized() * speed
		var able = not is_lock && not is_hitstun && not is_blockstun
		
		#MANEJA EL BLOQUEO
		if player_path == "/root/Main/HostPlayer" && input.get("input_vector") == Vector2.LEFT:
			is_blocking = true
		elif player_path == "/root/Main/ClientPlayer" && input.get("input_vector") == Vector2.RIGHT:
			is_blocking = true
		else:
			is_blocking = false
		
		#MANEJA EL PUÑETAZO 
		if input.get("attack", false) && able:
			throw_punch()
			#TODO: ACTIVAR EL PUÑETAZO
		
		#MANEJA LA PATADA
		if input.get("attack", false) && is_cancelable:
			throw_kick()
			is_lock_kick = true
			is_cancelable = false
			kick_timer.start()
			#TODO: ACTIVAR LA PATADA
			
		#MANEJA EL MOVIMIENTO
		if not _will_collide(motion) && able:
			position += motion
		#MANEJA LAS ANIMAICONES
		animation_tree(input)
		
		#MANEJA LAS COLISIONES
		check_colission()

func _will_collide(motion: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var shape = player_pushbox.shape

	var params = Physics2DShapeQueryParameters.new()
	params.set_shape(shape)
	params.set_transform(Transform2D(0, global_position + motion))
	params.set_margin(15)
	params.exclude = [self]

	var result = space_state.intersect_shape(params, 1)
	return result.size() > 0

func manage_hit(killing_blow: bool):
	
	clear_punch()
	clear_kick()
	if not is_blocking:
		if not killing_blow:
			SyncManager.play_sound(str(get_path()) + ":blow", BlowSound)
			hit_animation.play("HitAnimation")
			is_hitstun = true
			hitstun_timer.start()
		else:
			SyncManager.play_sound(str(get_path()) + ":killing_blow", KillingBlowSound)
			death_animation.play("DeathAnimation")
			is_lock = true
			emit_signal("game_lost")
	else:
		is_blockstun = true
		SyncManager.play_sound(str(get_path()) + ":block", BlockSound)
		blockstun_timer.start()
		modify_shield(-1)
	
	animation_tree({})

func _on_HitstunTimer_timeout():
	is_hitstun = false
	hitstun_timer.stop()

func _on_BlockstunTimer_timeout():
	is_blockstun = false
	blockstun_timer.stop()
	print("YA NO ESTOY EN BLOCKSTUN")

func modify_shield(value: int):
	shield_count += value
	emit_signal("update_shield")

func set_facing_left():
	if player_path != "/root/Main/HostPlayer":
		$Animations/IdleSprites.scale.x = -$Animations/IdleSprites.scale.x
		$Animations/PunchSprites.scale.x = -$Animations/PunchSprites.scale.x
		$Animations/KickSprites.scale.x = -$Animations/KickSprites.scale.x
		$Animations/MoveSprites.scale.x = -$Animations/MoveSprites.scale.x
		$Animations/MoveBackSprites.scale.x = -$Animations/MoveBackSprites.scale.x
		$Animations/HitSprites.scale.x = -$Animations/HitSprites.scale.x
		$Animations/DeathSprites.scale.x = -$Animations/DeathSprites.scale.x
		$Punch.scale.x = -$Punch.scale.x
		$PunchHitBox.scale.x = -$PunchHitBox.scale.x
		$Kick.scale.x = -$Kick.scale.x
		$KickHitBox.scale.x = -$KickHitBox.scale.x

func _on_PunchTimer_timeout():
	punch_timer.stop()
	is_lock = false
	is_cancelable = false
	$Punch.monitorable = false

func _on_KickTimer_timeout():
	kick_timer.stop()
	is_lock_kick = false
	is_cancelable = false
	$Kick.monitorable = false
	
func _save_state() -> Dictionary:
	return { "position": position,
		"is_lock": is_lock,
		"is_lock_kick": is_lock_kick,
		"is_cancelable": is_cancelable,
		"is_blocking": is_blocking,
		"is_hitstun": is_hitstun,
		"is_blockstun": is_blockstun,
		"shield_count": shield_count,
		"is_game_over": is_game_over,
		
		"idle_sprites": $Animations/IdleSprites.visible,
		"move_sprites": $Animations/MoveSprites.visible,
		"move_back_sprites": $Animations/MoveBackSprites.visible,
		"punch_sprites": $Animations/PunchSprites.visible,
		"kick_sprites": $Animations/KickSprites.visible,
		"hit_sprites": $Animations/HitSprites.visible,
		"death_sprites": $Animations/DeathSprites.visible
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
	is_game_over = state["is_game_over"]
	$Animations/IdleSprites.visible = state["idle_sprites"]
	$Animations/MoveSprites.visible = state["move_sprites"]
	$Animations/MoveBackSprites.visible = state["move_back_sprites"]
	$Animations/PunchSprites.visible = state["punch_sprites"]
	$Animations/KickSprites.visible = state["kick_sprites"]
	$Animations/HitSprites.visible = state["hit_sprites"]
	$Animations/DeathSprites.visible = state["death_sprites"]

func animation_tree(input: Dictionary):
	
	var motion = input.get("input_vector", Vector2.ZERO).normalized() * speed
	
	if not _will_collide(motion) && motion != Vector2.ZERO && not is_lock:
		if player_path == "/root/Main/HostPlayer" && input.get('input_vector') == Vector2.LEFT:
			update_sprites('MoveBackSprites')
		elif player_path != "/root/Main/HostPlayer" && input.get('input_vector') == Vector2.RIGHT:
			update_sprites('MoveBackSprites')
		else:
			update_sprites('MoveSprites')
	else:
		update_sprites('IdleSprites')
	
	if is_blockstun:
		update_sprites('IdleSprites')
	
	if punch_animation.is_playing():
		update_sprites('PunchSprites')
	if kick_animation.is_playing():
		update_sprites('KickSprites')
	if hit_animation.is_playing():
		update_sprites('HitSprites')
	if death_animation.is_playing():
		update_sprites('DeathSprites')

func update_sprites(sprites_name: String):
	var sprite_names = [
		'IdleSprites',
		'MoveSprites',
		'MoveBackSprites',
		'PunchSprites',
		'KickSprites',
		'HitSprites',
		'DeathSprites'
	]
	var container = $Animations
	for i in sprite_names:
		var node = container.get_node_or_null(i)
		if node:
			node.visible = (i == sprites_name)

func throw_punch():
	is_lock = true
	punch_animation.play("PunchAnimation")
	punch_timer.start()
	punch_startup_timer.start()
	$Punch.monitorable = true
	SyncManager.play_sound(str(get_path()) + ":blow", ThrowSound)
	animation_tree({})

func throw_kick():
	is_cancelable = false
	kick_animation.play("KickAnimation")
	kick_timer.start()
	kick_startup_timer.start()
	$Kick.monitorable = true
	SyncManager.play_sound(str(get_path()) + ":blow", ThrowSound)
	animation_tree({})

func _on_PunchStartupTimer_timeout():
	punch_startup_timer.stop()
	$PunchHitBox/PunchActiveTimer.start()
	$PunchHitBox.monitoring = true

func _on_PunchActiveTimer_timeout():
	print("se puede cancelar")
	is_cancelable = true
	$PunchHitBox/PunchActiveTimer.stop()
	$PunchHitBox.monitoring = false

func _on_KickStartupTimer_timeout():
	kick_startup_timer.stop()
	$KickHitBox/KickActiveTimer.start()
	$KickHitBox.monitoring = true

func _on_KickActiveTimer_timeout():
	$KickHitBox/KickActiveTimer.stop()
	$KickHitBox.monitoring = false

func check_colission():
	for body in $PunchHitBox.get_overlapping_areas():
		if body.get_parent().get_path() != self.get_path():
			print("PUÑO CHOCA CON ALGO")
			if body.get_parent().has_method('manage_hit'):
				body.get_parent().manage_hit(false)
	
	for body in $KickHitBox.get_overlapping_areas():
		if body.get_parent().get_path() != self.get_path():
			print("PATADA CHOCA CON ALGO")
			if body.get_parent().has_method('manage_hit'):
				body.get_parent().manage_hit(true)

func clear_punch():
	is_lock = false
	punch_timer.stop()
	punch_startup_timer.stop()
	$PunchHitBox/PunchActiveTimer.stop()
	$Punch.monitorable = false
	$PunchHitBox.monitoring = false

func clear_kick():
	kick_timer.stop()
	kick_startup_timer.stop()
	$KickHitBox/KickActiveTimer.stop()
	$Kick.monitorable = false
	$KickHitBox.monitoring = false

func reset():
	position = original_position
	is_lock = false
	is_lock_kick = false
	is_cancelable = false
	is_hitstun = false
	is_blockstun = false
	is_blocking = false
	shield_count = 3
