extends Control

@onready var message_input: TextEdit = $TextEdit
@onready var message_list: UiMessageList = $MessageList

var last_click_msg_id: String
var replying_to: Message:
	set(val):
		$StatusLabel.text = "Replying to @" + val.author_name + ": " + val.content if val else ""
		replying_to = val

var loading: bool = true

func _ready() -> void:
	Discord.guild = OS.get_environment("GUILD")
	Discord.channel = OS.get_environment("CHANNEL")
	
	Discord.connect_to_disocrd()
	
	Discord.on_ready.connect(self._on_discord_ready)
	Discord.on_message.connect(self.message_list.add_message)

	self.message_list.add_message(Message.system_message("Loading..."))

	self.message_list.load_more_requested.connect(_load_more_requested)
	self.message_list.click_message.connect(_click_message)

func _on_discord_ready() -> void:
	print("Ready!")

	if Discord.channel:
		var messages = await Discord.fetch_messages(Discord.channel)
		messages.reverse()

		self.message_list.clear_messages()

		for message in messages:
			self.message_list.add_message(message)

	self.loading = false

func _click_message(message: Message) -> void:
	if last_click_msg_id == message.message_id:
		self.replying_to = message

	self.last_click_msg_id = message.message_id

func _load_more_requested(direction: int, ref_message: Message) -> void:
	if loading: return

	if direction > 0:
		loading = true
		var messages = await Discord.fetch_messages_before(Discord.channel, ref_message.message_id)
		messages.reverse()
		messages.append_array(self.message_list._messages)

		var current_offset = self.message_list._scroll_offset
		self.message_list.clear_messages()

		for message in messages:
			self.message_list.add_message(message)

		self.message_list._scroll_offset = current_offset
		loading = false

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
