extends Node

enum CONNECT_STATUS {
	CONNECTED,
	ERROR,
	NOT_CONNECTED
}

var current_status : CONNECT_STATUS = CONNECT_STATUS.NOT_CONNECTED :
	set(value):
		current_status = value
		status_changed.emit(current_status)
	
signal status_changed(status: CONNECT_STATUS)
signal disonnected
signal chatter_joined(chatter_name : String)
signal chatter_message(chatter_name: String, message: String)

var joined_chatter_names : Dictionary[String, bool] = {}
var claimed_chatter_names : Dictionary[String, bool] = {}

func _ready() -> void:
	VerySimpleTwitch.chat_message_received.connect(print_chatter_message)
	VerySimpleTwitch.chat_connected.connect(func(channel_name): 
		print("Connected to chat " + channel_name)
		current_status = CONNECT_STATUS.CONNECTED
	)

func connect_to_channel(channel_name: String):
	current_status = CONNECT_STATUS.NOT_CONNECTED
	VerySimpleTwitch.login_chat_anon(channel_name)
	GameAnalytics.send_twitch_connection_event(channel_name)
	
	
func disconnect_from_channel():
	VerySimpleTwitch.end_chat_client()
	current_status = CONNECT_STATUS.NOT_CONNECTED
	joined_chatter_names = {}
	claimed_chatter_names = {}
	disonnected.emit()

func clear_claimed_chatters():
	claimed_chatter_names = {}

func print_chatter_message(chatter: VSTChatter):
	if claimed_chatter_names.has(chatter.tags.display_name):
		chatter_message.emit(chatter.tags.display_name, chatter.message)
		return
	if true or chatter.message.strip_edges() == "join":
		if not joined_chatter_names.has(chatter.tags.display_name): 
			joined_chatter_names[chatter.tags.display_name] = chatter.is_sub()
			print("Added chatter %s" % [chatter.tags.display_name])
			chatter_joined.emit(chatter.tags.display_name)
