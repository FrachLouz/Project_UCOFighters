extends Node2D

const DummyNetworkAdaptor = preload("res://addons/godot-rollback-netcode/DummyNetworkAdaptor.gd")

onready var main_menu = $CanvasLayer/MainMenu
onready var connection_panel = $CanvasLayer/ConnectionPanel
onready var host_field = $CanvasLayer/ConnectionPanel/GridContainer/HostField
onready var port_field = $CanvasLayer/ConnectionPanel/GridContainer/PortField
onready var message_label = $CanvasLayer/ConnectionLabel
onready var sync_label = $CanvasLayer/SyncLostLabel

#VARIABLES DE UI, SUJETAS A CAMBIO
onready var win_screen = $CanvasLayer/WinScreenLabel
onready var host_shields = $CanvasLayer/HostShields
onready var client_shields = $CanvasLayer/ClientShields
onready var hostwin_label = $CanvasLayer/HostWins
onready var clientwin_label = $CanvasLayer/ClientWins

var host_wins = 0
var client_wins = 0

func _ready() -> void:
	get_tree().connect("network_peer_connected", self, "_on_network_peer_connected")
	get_tree().connect("network_peer_disconnected", self, "_on_network_peer_disconnected")
	get_tree().connect("server_disconnected", self, "_on_server_discconnected")
	SyncManager.connect("sync_started", self, "_on_SyncManager_sync_started")
	SyncManager.connect("sync_stopped", self, "_on_SyncManager_sync_stopped")
	SyncManager.connect("sync_lost", self, "_on_SyncManager_sync_lost")
	SyncManager.connect("sync_regained", self, "_on_SyncManager_sync_reagined")
	SyncManager.connect("sync_error", self, "_on_SyncManager_sync_error")


func _on_HostButton_pressed():
	var peer = NetworkedMultiplayerENet.new()
	peer.create_server(int(port_field.text), 1)
	get_tree().network_peer = peer
	main_menu.visible = false
	connection_panel.visible = false
	message_label.text = "Listening..."
	
func _on_ClientButton_pressed():
	var peer = NetworkedMultiplayerENet.new()
	peer.create_client(host_field.text, int(port_field.text))
	get_tree().network_peer = peer
	main_menu.visible = false
	connection_panel.visible = false
	message_label.text = "Connecting..."

func _on_network_peer_connected(peer_id: int):
	message_label.text = "Connected!"
	SyncManager.add_peer(peer_id)
	
	$HostPlayer.set_network_master(1)
	if get_tree().is_network_server():
		$ClientPlayer.set_network_master(peer_id)
	else:
		$ClientPlayer.set_network_master(get_tree().get_network_unique_id())
	
	if get_tree().is_network_server():
		message_label.text = "Starting..."
		yield(get_tree().create_timer(1.0), "timeout")
		SyncManager.start()

func _on_network_peer_disconnected(peer_id: int):
	message_label.text = "Disconnected"
	SyncManager.remove_peer(peer_id)

func _on_server_disconnected() -> void:
	_on_network_peer_disconnected(1)

func _on_ResetButton_pressed():
	SyncManager.stop()
	SyncManager.clear_peers()
	var peer = get_tree().network_peer
	if peer:
		peer.close_connection()
	get_tree().reload_current_scene()

func _on_SyncManager_sync_started() -> void:
	message_label.text = "Started!"

func _on_SyncManager_sync_stopped() -> void:
	pass

func _on_SyncManager_sync_lost() -> void:
	sync_label.visible = true

func _on_yncManager_sync_regained() -> void:
	sync_label.visible = false

func _on_SyncManager_sync_error(msg: String) -> void:
	message_label.text = "fatal sync error : " + msg
	sync_label.visible = false
	
	var peer = get_tree().network_peer
	if peer:
		peer.close_connection()
	get_tree().reload_current_scene()


func _on_OnlineButton_pressed():
	main_menu.visible = false
	connection_panel.popup_centered()
	SyncManager.reset_network_adaptor()


func _on_OfflineButton_pressed():
	main_menu.visible = false
	SyncManager.network_adaptor = DummyNetworkAdaptor.new()
	SyncManager.start()
	$ClientPlayer.input_prefix = "player2_"

func restart_game():
	yield(get_tree().create_timer(0.2), "timeout")
	$ClientPlayer.reset()
	$HostPlayer.reset()

func _on_HostPlayer_game_lost():
	win_screen.text = "PLAYER 2 WINS"
	win_screen.visible = true
	client_wins += 1
	clientwin_label.text = String(client_wins)
	stop_match()
	yield(get_tree().create_timer(3.0), "timeout")
	restart_game()
	win_screen.visible = false
	
func _on_ClientPlayer_game_lost():
	win_screen.text = "PLAYER 1 WINS"
	win_screen.visible = true
	host_wins += 1
	hostwin_label.text = String(host_wins)
	stop_match()
	yield(get_tree().create_timer(3.0), "timeout")
	#yield(wait_for_restart(), "completed")
	restart_game()
	win_screen.visible = false

func _on_HostPlayer_update_shield():
	host_shields.text = String($HostPlayer.shield_count)
	
func _on_ClientPlayer_update_shield():
	client_shields.text = String($ClientPlayer.shield_count)

func stop_match():
	$HostPlayer.is_lock = true
	$ClientPlayer.is_lock = true

func wait_for_restart():
	while true:
		yield(get_tree(), "idle_frame")
		if Input.is_action_just_pressed("player1_attack") or Input.is_action_just_pressed("player2_attack"):
			break
