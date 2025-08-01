extends KinematicBody2D  # <--- cambia de Node2D a KinematicBody2D

const Punch = preload("res://Attacks/Punch.tscn")
const Kick = preload("res://Attacks/Kick.tscn")
const PuncHitbox = preload("res://Attacks/PunchHitbox.tscn")

var input_prefix := "player1_"
var speed := 8

onready var collision_shape = $CollisionShape2D
onready var is_player1_lock = false #En true, evitara que el jugador realize cualquier accion
onready var is_player1_lock_kick = false
onready var is_player1_cancelable = false
onready var is_player2_lock = false #En true, evitara que el jugador realize cualquier accion
onready var is_player2_lock_kick = false
onready var is_player2_cancelable = false

func _ready() -> void:
	SyncManager.connect("scene_spawned", self, "_on_SyncManager_scene_spawned")
	SyncManager.connect("scene_despawned", self, "_on_SyncManager_scene_despawned")

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
	
	if input.get("attack", false) && not is_player1_lock && not is_player1_lock_kick:
		SyncManager.spawn("Punch", get_parent(), Punch, { position = global_position, player = self})
		
	if input.get("attack", false) && is_player1_cancelable:
		SyncManager.spawn("Kick", get_parent(), Kick, { position = global_position, player = self})
	
	if not _will_collide(motion) && not is_player1_lock && not is_player1_lock_kick:
		position += motion

func _will_collide(motion: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var shape = collision_shape.shape

	var params = Physics2DShapeQueryParameters.new()
	params.set_shape(shape)
	params.set_transform(Transform2D(0, global_position + motion))
	params.set_margin(0.2)
	params.exclude = [self]

	var result = space_state.intersect_shape(params, 1)
	return result.size() > 0

func _on_SyncManager_scene_spawned(name, spawned_node, scene, data) -> void:
	if name == 'Punch':
			is_player1_lock = true
	if name == 'Kick':
		is_player1_lock_kick = true
		
func _on_SyncManager_scene_despawned(name, despawned_node) -> void:
	if name == 'Punch':
		#despawned_node.disconnect("hit", self, "_on_attack_hit")
		
		is_player1_lock = false
		is_player1_cancelable = false
	if name == 'PunchHitbox':
		is_player1_cancelable = true
	if name == 'Kick':
		is_player1_lock_kick = false

func _save_state() -> Dictionary:
	return { "position": position,
		"is_player1_lock": is_player1_lock,
		"is_player1_cancelable": is_player1_cancelable,
		"is_player_lock_kick": is_player1_lock_kick}

func _load_state(state: Dictionary) -> void:
	position = state["position"]
	is_player1_lock = state["is_player1_lock"]
	is_player1_cancelable = state["is_player1_cancelable"]
	is_player1_lock_kick = state["is_player_lock_kick"]
