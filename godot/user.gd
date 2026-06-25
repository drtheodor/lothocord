class_name User

var user_id: StringName
var username: String
var global_name: String
var avatar_id: StringName

static func from_json(dict: Dictionary) -> User:
	var user = User.new()
	user.user_id = dict["id"]
	user.username = dict["username"]
	user.global_name = dict["global_name"]
	user.avatar_id = dict["avatar"]
	
	return user
