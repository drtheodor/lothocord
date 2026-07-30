class_name Channel

var channel_id: StringName
var channel_name: String

func _init(_channel_id: StringName, _channel_name: String) -> void:
	self.channel_id = _channel_id
	self.channel_name = _channel_name

static func from_json(data: Dictionary) -> Channel:
	var _channel_name: String
	if data.has("name") and data["name"]:
		_channel_name = data["name"]
	elif data.has("recipients") and data["recipients"] is Array and data["recipients"].size() > 0:
		var recipient: Variant = data["recipients"][0]
		if recipient is Dictionary:
			_channel_name = recipient.get("global_name", "") if recipient.get("global_name", "") != "" else recipient.get("username", "")

	var _channel_id: StringName = data["id"]
	return Channel.new(_channel_id, _channel_name)


enum Type {
	TEXT = 0,
	VOICE = 2,
	CATEGORY = 4,
	UNKNOWN,
}

class GuildChannel extends Channel:

	var channel_type: Type
	var parent_id: StringName
	var position: int

	func _init(_channel_id: StringName, _channel_name: String, _type: Type, _parent_id: StringName, _position: int) -> void:
		super(_channel_id, _channel_name)

		self.channel_type = _type
		self.parent_id = _parent_id
		self.position = _position

	static func from_json(data: Dictionary) -> GuildChannel:
		var _channel_name: String = data["name"]
		var _channel_id: StringName = data["id"]

		var _type: Type = data.get("type", 0) as Type

		var _parent_id: StringName = data["parent_id"] if data.get("parent_id") else &""

		var _position: int = data["position"]
		return GuildChannel.new(_channel_id, _channel_name, _type, _parent_id, _position)
