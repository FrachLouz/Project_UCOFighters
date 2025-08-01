extends KinematicBody2D  # <--- cambia de Node2D a KinematicBody2D

const Punch = preload("res://Attacks/Punch.tscn")
const Kick = preload("res://Attacks/Kick.tscn")
const PuncHitbox = preload("res://Attacks/PunchHitbox.tscn")

onready var collision_shape = $CollisionShape2D
onready var main = get_tree().get_root().get_node("Main")

var input_prefix := "player1_"
var speed := 8
var is_lock = false
var is_lock_kick = false
var is_cancelable = false

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
		
		if input.get("attack", false) && not is_lock && not is_lock_kick:
			SyncManager.spawn("Punch", get_parent(), Punch, { position = global_position, player = self})
			
		if input.get("attack", false) && is_cancelable:
			SyncManager.spawn("Kick", get_parent(), Kick, {position = global_position, player = self})
			
		if not _will_collide(motion) && not is_lock && not is_lock_kick:
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
	
	if name == 'Punch' and data['player_path'] == self.get_path():
		is_lock = true
	
	if name == 'Kick' and data['player_path'] == self.get_path():
		is_lock_kick = true
		is_cancelable = false

func _on_SyncManager_scene_despawned(name, despawned_node) -> void:
	
	if name == 'Punch':
		var player_path = despawned_node.player_path
		var player_node = get_node(player_path)
		if player_node == self:
			is_lock = false
	
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

func _save_state() -> Dictionary:
	return { "position": position,
		"is_lock": is_lock,
		"is_lock_kick": is_lock_kick,
		"is_cancelable": is_cancelable
		}

func _load_state(state: Dictionary) -> void:
	position = state["position"]
	is_lock = state["is_lock"]
	is_lock_kick = state["is_lock_kick"]
	is_cancelable = state["is_cancelable"]

