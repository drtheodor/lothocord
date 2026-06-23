extends Control

func _ready() -> void:
	Discord.on_ready.connect(self._on_discord_ready)
	Discord.on_message.connect(self._on_message)

func _on_discord_ready() -> void:
	print("ready!")
	
	Discord.channel = "1267481310583066735"
	
	var messages = await Discord.fetch_messages(Discord.channel)
	messages.reverse()
	for message in messages:
		self._on_message(message)

func _on_message(message: Message):
	%MessageList.add_message(message)
