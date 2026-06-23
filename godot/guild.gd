class_name Guild

var guild_id: String
var guild_name: String
var guild_icon: String
var channels: Array[Channel.GuildChannel] = []

func _init(_guild_id: String, _guild_name: String, _guild_icon: String, _channels: Array[Channel.GuildChannel]) -> void:
	self.guild_id = _guild_id
	self.guild_name = _guild_name
	self.guild_icon = _guild_icon
	self.channels = _channels

# TODO: improve typing
static func from_json(data: Dictionary) -> Guild:
	var id: String = data["id"]
	
	if data.get("unavailable"):
		return Guild.new(id, "Unavailable", "", [])
	
	var props: Variant = data["properties"]
	var name: String = props["name"]
	var icon: String = props["icon"] if props["icon"] else ""
	
	var _channels: Array[Channel.GuildChannel] = []
	var categories: Dictionary[String, Array] = {}
	
	for raw_channel: Dictionary in data["channels"]:
		var channel: Channel.GuildChannel = Channel.GuildChannel.from_json(raw_channel)
		
		if not channel.parent_id:
			_channels.append(channel)
		else:
			categories.get_or_add(channel.parent_id, []).append(channel)
	
	_channels.sort_custom(_sort_orphans)
	
	var sorted_channels: Array[Channel.GuildChannel] = []
	
	for channel: Channel.GuildChannel in _channels:
		sorted_channels.append(channel)
		if channel.channel_type == Channel.Type.CATEGORY:
			var children: Array = categories.get(channel.channel_id, [])
			
			if children:
				children.sort_custom(_sort_children)
				sorted_channels.append_array(children)
	
	return Guild.new(id, name, icon, sorted_channels)
	
static func _sort_orphans(a: Channel.GuildChannel, b: Channel.GuildChannel) -> bool:
	return (a.position + 100 * int(a.channel_type == Channel.Type.CATEGORY)) < (
		b.position + 100 * int(b.channel_type == Channel.Type.CATEGORY))

static func _sort_children(a: Channel.GuildChannel, b: Channel.GuildChannel) -> bool:
	return (a.position + 100 * int(a.channel_type == Channel.Type.VOICE)) < (
		b.position + 100 * int(b.channel_type == Channel.Type.VOICE))
