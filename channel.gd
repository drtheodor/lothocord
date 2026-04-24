extends Control

@onready var message_list: MessageList = %MessageList
@onready var channel_list: VBoxContainer = %ChannelList
@onready var message_input: CodeEdit = %NewMessageInput
@onready var guild_list: Container = %GuildList
@onready var status_bar: Label = %StatusBar
@onready var cancel_reply_btn: Button = %CancelReply

@onready var scroll_container: ScrollContainer = $HBoxContainer/Main/ScrollContainer
@onready var channel_label: Label = $HBoxContainer/Main/TopPanel/ChannelLabel
@onready var user_pref: Label = $HBoxContainer/Sidebar/UserPref/Sort/Name
@onready var user_pref_avatar: TextureRect = $HBoxContainer/Sidebar/UserPref/Sort/Rounder/Avatar
@onready var context: Window = $MessageContext

const MessageScene: PackedScene = preload("res://message.tscn")
const ChannelItemScene: PackedScene = preload("res://channel_item.tscn")
const ChannelCategoryItemScene: PackedScene = preload("res://channel_category_item.tscn")
const GuildItemScene: PackedScene = preload("res://guild_item.tscn")

var _busy: bool
var _typing_stack: Dictionary[String, int] = {}
var _typing_timer: Timer = Timer.new()

var last_message: UiMessage
var pending_messages: Dictionary[String, Node] = {}

var _hover_message: Message
var _replying_to: Message:
	set(value):
		_replying_to = value
		
		if value:
			self.status_bar.text = "Replying to @" + value.author_name
			self.status_bar.visible = true
			self.cancel_reply_btn.visible = true
			
			self.message_input.grab_focus()
		else:
			self.status_bar.visible = false
			self.cancel_reply_btn.visible = false
			self.status_bar.text = ""

func _ready() -> void:
	if OS.get_environment("THEME") == "transparent":
		self.get_window().transparent = true
	
	Discord.on_ready.connect(self._on_discord_ready)
	Discord.on_message.connect(self._on_message)
	Discord.on_typing.connect(self._on_typing)
	
	self.context.on_reply.connect(func() -> void: self._replying_to = self._hover_message)
	
	_typing_timer.one_shot = false
	_typing_timer.autostart = true
	_typing_timer.wait_time = 1
	_typing_timer.timeout.connect(self._update_typing)
	
	self.add_child(self._typing_timer)
	
	message_list.add_message(Message.system_message("Lorem ipsum dolor sit amet, consectetur adipiscing elit. Suspendisse scelerisque justo elementum magna posuere, eu laoreet mi dictum. Curabitur in lacinia nulla. Aliquam ac ipsum neque. Cras aliquet posuere condimentum. Vestibulum tempor ut nisi sit amet porta. Vivamus a ipsum posuere, luctus ex ac, volutpat eros. Quisque interdum leo non mi scelerisque maximus. Curabitur pharetra, urna vitae auctor ultricies, mauris purus accumsan arcu, dapibus mollis lacus nisl vitae dui. Duis sagittis id leo pulvinar lacinia. In quis purus nec ipsum sagittis finibus. Nunc at volutpat mauris, eu tempor nisi. Integer id purus nulla. Aenean ut elit et elit vestibulum egestas a ac lacus. Donec mi erat, interdum vel blandit et, tincidunt facilisis nunc."))
	message_list.add_message(Message.system_message("Morbi sollicitudin, tellus ut ultricies convallis, enim velit auctor orci, eget venenatis neque lorem id purus. Phasellus congue eleifend dolor at porta. Sed tincidunt augue vel sem tempus vulputate. Donec lacinia nulla bibendum sapien cursus interdum. Donec non ligula vel arcu rhoncus consequat. Nam maximus pharetra lectus, sit amet auctor augue. Sed tortor mauris, sodales sed fringilla in, tempus vitae dui. Donec lobortis arcu nec diam cursus sollicitudin. Proin ac tortor et dolor vestibulum consequat ut non arcu. Integer dictum sapien id sem lacinia volutpat."))

func _init_guild_channels(channels: Array[Channel.GuildChannel]) -> void:
	for child: Node in channel_list.get_children():
		child.queue_free()
	
	var last_category: FoldableContainer
	for channel: Channel.GuildChannel in channels:
		var ui_channel: Node
		if channel.channel_type == Channel.Type.CATEGORY:
			ui_channel = ChannelCategoryItemScene.instantiate()
			last_category = ui_channel
		else:
			ui_channel = ChannelItemScene.instantiate()
			ui_channel.clicked.connect(_on_channel_change)
		
		if ui_channel != last_category and last_category:
			last_category.add_node(ui_channel)
		else:
			channel_list.add_child(ui_channel)
		
		ui_channel.set_channel(channel)

func _on_channel_change(channel: Channel) -> void:
	if _busy: return
	
	self.message_input.editable = true
	
	Discord.channel = channel.channel_id
	
	self.channel_label.text = channel.channel_name
	
	# TODO: move api calls to `Discord`
	self._fetch_messages()

func _fetch_messages() -> void:
	self._busy = true
	
	var messages: Array[Message] = await Discord.fetch_messages(Discord.channel)
	messages.reverse()
	
	message_list.clear_messages()

	self.last_message = null

	for message: Message in messages:
		message_list.add_message(message)

	self.scroll_to_bottom()
	self._busy = false
	
	Discord.mark_as_read(Discord.channel, messages[-1].message_id)

func _add_pending_message(text: String, nonce: int) -> void:
	var pending: UiMessage = MessageScene.instantiate()
	message_list.add_child(pending)
	
	var message: Message = Message.with_user(Discord.user)
	
	message.referenced = _replying_to
	message.timestamp = int(Time.get_unix_time_from_system())
	message.nonce = str(nonce)
	message.tokens = [Message.TextToken.new(text)]
	
	pending.set_pending()
	pending.add_message(message)
	
	pending_messages[str(nonce)] = pending
	
	if _is_near_bottom():
		scroll_to_bottom()

func _on_discord_ready() -> void:
	for guild: Guild in Discord.guild_cache.values():
		var guild_item: UiGuildItem = GuildItemScene.instantiate()
		guild_item.clicked.connect(self._on_guild_change)
		
		self.guild_list.add_child(guild_item)
		
		guild_item.set_guild(guild)
	
	self.user_pref.text = Discord.user.global_name
	self.user_pref_avatar.texture = await Discord.get_avatar(Discord.user.user_id, Discord.user.avatar_id)

func _on_guild_change(guild: Guild) -> void:
	Discord.follow_guild(guild.guild_id)
	self._init_guild_channels(guild.channels)

func _on_message(message: Message, scroll: bool = true) -> void:
	var pending: UiMessage = pending_messages.get(message.nonce)
	
	if pending:
		pending.queue_free()
	
	if not self.last_message or not self._should_group(last_message.messages[-1], message):
		var new_message: UiMessage = MessageScene.instantiate()
		
		new_message.mouse_entered_msg.connect(self._on_message_hover)
		
		self.last_message = new_message
		message_list.add_child(self.last_message)
	
	# FIXME: temp await fix since there's no Promise.all :(
	self.last_message.add_message(message)
	
	if scroll and _is_near_bottom():
		self.scroll_to_bottom()

func _on_typing(user: User) -> void:
	self._typing_stack[user.global_name] = Util.get_time_millis() + 3000
	self._update_typing()

func _update_typing() -> void:
	if self._typing_stack:
		var people: Array[String] = self._typing_stack.keys()
		
		for key: String in people:
			if Util.get_time_millis() > self._typing_stack[key]:
				self._typing_stack.erase(key)
			
		if people.size() == 1:
			self.status_bar.text = "󰇘 %s is typing..." % people[0]
		else:
			self.status_bar.text = "󰇘 %s are typing..." % ", ".join(people)
		
		self.status_bar.visible = true
	else:
		self.status_bar.visible = self._replying_to != null

func _on_message_hover(label: Control, message: Message) -> void:
	self._hover_message = message
	var message_position: Vector2 = label.get_screen_position()
	
	message_position -= Vector2(10, 4)
	message_position.x += label.size[0] - context.size[0]
	
	context.visible = true
	context.position = message_position
	
	label.grab_focus()

func _is_near_bottom() -> bool:
	var vbar: ScrollBar = scroll_container.get_v_scroll_bar()
	if not vbar:
		return true
	
	return (vbar.max_value - scroll_container.scroll_vertical) < 2000

func _should_group(prev_message: Message, new_message: Message) -> bool:
	# TODO: figure out why the fuck its being funny about timestamps
	return not new_message.referenced and abs(prev_message.timestamp - new_message.timestamp) <= 6 * 1000 and prev_message.author_id == new_message.author_id

func scroll_to_bottom() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	
	var vbar: ScrollBar = scroll_container.get_v_scroll_bar()
	
	if vbar:
		scroll_container.scroll_vertical = int(vbar.max_value) + 1
	else:
		# Calculate manually
		var content: Node = scroll_container.get_child(0)
		if content:
			scroll_container.scroll_vertical = content.size.y - scroll_container.size.y

func add_error_message(text: String) -> void:
	self._on_message(Message.system_message(text))

func _on_code_edit_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if event.shift_pressed:
				event.shift_pressed = false
				return

			# Cancel the default behavior
			message_input.accept_event()

			if message_input.text.strip_edges().is_empty():
				return

			var text_to_send: String = message_input.text
			message_input.text = ''
			
			var nonce: int = Discord.send_message(Discord.channel, text_to_send, _replying_to.message_id if _replying_to else "",)
			_add_pending_message(text_to_send, nonce)
			
			self._replying_to = null

func _on_cancel_reply_pressed() -> void:
	self._replying_to = null
