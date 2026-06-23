class_name User

var user_id: String
var username: String
var global_name: String
var avatar_id: String

func _init(_user_id: String, _username: String, _global_name: String, _avatar_id: String) -> void:
	self.user_id = _user_id
	self.username = _username
	self.global_name = _global_name
	self.avatar_id = _avatar_id

static func from_json(dict: Dictionary) -> User:
	var _user_id: String = dict["id"]
	var _username: String = dict["username"]
	var _global_name: String = dict["global_name"]
	var _avatar_id: String = dict["avatar"]
	
	return User.new(_user_id, _username, _global_name, _avatar_id)
