extends Control

@onready var message_input = $TextEdit

var last_click_msg_id: String
var replying_to: Message:
	set(val):
		$StatusLabel.text = "Replying to @" + val.author_name + ": " + val.content if val else ""
		replying_to = val

func _ready() -> void:
	Discord.on_ready.connect(self._on_discord_ready)
	Discord.on_message.connect(self._on_message)
	
	_on_message(Message.system_message("Loading..."))

var loading = false

func _on_discord_ready() -> void:
	print("ready!")
	
	Discord.channel = OS.get_environment("CHANNEL")
	
	var messages = await Discord.fetch_messages(Discord.channel)
	messages.reverse()
	
	%MessageList.clear_messages()
	
	for message in messages:
		%MessageList.add_message(message)
	
	%MessageList.load_more_requested.connect(_load_more_requested)
	%MessageList.click_message.connect(_click_message)

func _click_message(message: Message) -> void:
	if last_click_msg_id == message.message_id:
		self.replying_to = message
	
	self.last_click = message.message_id

func _load_more_requested(direction: int, ref_message: Message) -> void:
	if loading: return
	
	if direction > 0:
		loading = true
		var messages = await Discord.fetch_messages_before(Discord.channel, ref_message.message_id)
		messages.reverse()
		messages.append_array(%MessageList._messages)
		
		var current_offset = %MessageList._scroll_offset
		%MessageList.clear_messages()
		
		for message in messages:
			%MessageList.add_message(message)
		
		%MessageList._scroll_offset = current_offset
		loading = false

func _on_message(message: Message):
	%MessageList.add_message(message)

func _on_code_edit_gui_input(event: InputEvent) -> void:
	if event is not InputEventKey: return
	
	if event.is_action_pressed(&"ui_cancel"):
		if self.replying_to:
			self.replying_to = null
	elif event.is_action_pressed(&"ui_accept"):
		if event.shift_pressed:
			event.shift_pressed = false
			return

		# Cancel the default behavior
		message_input.accept_event()

		if message_input.text.strip_edges().is_empty():
			return

		var text_to_send: String = message_input.text
		message_input.text = ''
		
		var nonce: int = Discord.send_message(Discord.channel, text_to_send, self.replying_to.message_id if self.replying_to else "")
		
		if self.replying_to:
			self.replying_to = null
		
		#_add_pending_message(text_to_send, nonce)
