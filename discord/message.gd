class_name Message

var author_name: String
var author_id: String
var author_avatar: String
var nonce: String

var message_id: String
var timestamp: int
var tokens: Array[Token]

var referenced: Message

# FIXME: this is bad
func content() -> String:
	var result: String = ""
	for token: Token in self.tokens:
		if token is TextToken:
			result += token.text
		elif token is LinkToken:
			result += token.url
	return result

static func system_message(text: String) -> Message:
	var message: Message = Message.new()
	message.author_name = "GDiscord"
	message.author_id = "643945264868098049"
	message.author_avatar = "c6a249645d46209f337279cd2ca998c7"
	message.timestamp = int(Time.get_unix_time_from_system())
	message.tokens = [Message.TextToken.new(text)]
	
	return message

static func with_user(user: User) -> Message:
	var message: Message = Message.new()
	message.author_name = user.global_name
	message.author_id = user.user_id
	message.author_avatar = user.avatar_id
	return message

static func from_json(data: Dictionary, short: bool = false) -> Message:
	var _message_id: String = data["id"]
	var author: Dictionary = data["author"]
	#var mentions = message_data["mentions"]
	#var mention_roles = message_data["mention_roles"]
	var attachments: Array = data.get("attachments", [])
	#var embeds: Array = data.get("embeds", [])
	var iso_timestamp: String = data["timestamp"]
	#var edited_timestamp: int = message_data["edited_timestamp"]
	
	var _author_id: String = author["id"]
	var _author_name: String = author["display_name"] if author.get("display_name") else author["global_name"] if author["global_name"] else author["username"] # I don't know why this fixes it but it doesl
	var _author_avatar: Variant = author.get("avatar")
	_author_avatar = _author_avatar if _author_avatar else ""
	
	var referenced_message: Dictionary = data.get("referenced_message", {})
	var _referenced: Message = Message.from_json(referenced_message, true) if referenced_message else null

	var _timestamp: int = Time.get_unix_time_from_datetime_string(iso_timestamp)
	var _nonce: String = data.get("nonce", "")
	
	var _content: String = data["content"]
	
	if short:
		_content = _content.replace("\n", "")
		if _content.length() > 120:
			_content = _content.substr(0, 120) + "…"
	
	var _tokens: Array[Token] = Token.parse(_content)
	
	for attachment: Dictionary in attachments:
		if attachment.has("url"):
			if not _tokens.is_empty():
				_tokens.append(TextToken.new("\n"))
			
			var url_attachment: String = str(attachment["url"])
			var is_image: bool = false
			
			if attachment.has("content_type"):
				var ct: String = str(attachment["content_type"]).to_lower()
				is_image = ct.begins_with("image/")
			
			if not is_image:
				is_image = Url.is_image(url_attachment)
			
			if is_image:
				_tokens.append(ImageToken.new(url_attachment))
			else:
				_tokens.append(TextToken.new("[file %s] " % url_attachment))
	
	var message: Message = Message.new()
	message.author_name = _author_name
	message.author_id = _author_id
	message.author_avatar = _author_avatar
	
	message.message_id = _message_id
	message.timestamp = _timestamp
	message.nonce = _nonce
	message.tokens = _tokens
	
	if _referenced:
		message.referenced = _referenced
	
	return message

class Token:
	
	enum Type {
		TEXT, LINK, IMAGE, USER, CHANNEL, EMOJI
	}
	
	var type: Type
	
	func _init(_type: Type) -> void:
		self.type = _type
	
	static func _process_text_segment(text: String) -> Array[Token]:
		var result: Array[Token] = []
		var matches: Array[RegExMatch] = Url.REGEX.search_all(text)
		var last_end: int = 0
		
		for match: RegExMatch in matches:
			var start: int = match.get_start()
			var end: int = match.get_end()
			
			# Text before the URL
			if start > last_end:
				var plain: String = text.substr(last_end, start - last_end)
				if plain.length() > 0:
					result.append(TextToken.new(plain))
			
			# The URL itself
			var url: String = match.get_string()
			result.append(LinkToken.new(url))
			last_end = end
		
		# Text after the last URL
		if last_end < text.length():
			var plain: String = text.substr(last_end)
			if plain.length() > 0:
				result.append(TextToken.new(plain))
		
		return result

	static func parse(input: String) -> Array[Token]:
		var tokens: Array[Token] = []
		var i: int = 0
		var n: int = input.length()
		
		while i < n:
			var ch: String = input[i]
			if ch == '<':
				var matched: bool = false
				var j: int = i + 1
				if j < n:
					var next: String = input[j]
					# Channel mention: <#123456>
					if next == '#':
						var id_end: int = _find_id_end(input, j + 1)
						if id_end != -1 and id_end < n and input[id_end] == '>':
							var id: String = input.substr(j + 1, id_end - (j + 1))
							tokens.append(ChannelToken.new(id))
							i = id_end + 1
							matched = true
					# User mention: <@123456>
					elif next == '@':
						var id_end: int = _find_id_end(input, j + 1)
						if id_end != -1 and id_end < n and input[id_end] == '>':
							var id: String = input.substr(j + 1, id_end - (j + 1))
							tokens.append(UserToken.new(id))
							i = id_end + 1
							matched = true
					# Static emoji: <:name:123456>
					elif next == ':':
						var name_start: int = j + 1
						var name_end: int = _find_char(input, ':', name_start)
						if name_end != -1:
							var id_start: int = name_end + 1
							var id_end: int = _find_id_end(input, id_start)
							if id_end != -1 and id_end < n and input[id_end] == '>':
								var name: String = input.substr(name_start, name_end - name_start)
								var id: String = input.substr(id_start, id_end - id_start)
								tokens.append(EmojiToken.new(name, id, false))
								i = id_end + 1
								matched = true
					# Animated emoji: <a:name:123456>
					elif next == 'a' and j + 1 < n and input[j + 1] == ':':
						var name_start: int = j + 2
						var name_end: int = _find_char(input, ':', name_start)
						if name_end != -1:
							var id_start: int = name_end + 1
							var id_end: int = _find_id_end(input, id_start)
							if id_end != -1 and id_end < n and input[id_end] == '>':
								var name: String = input.substr(name_start, name_end - name_start)
								var id: String = input.substr(id_start, id_end - id_start)
								tokens.append(EmojiToken.new(name, id, true))
								i = id_end + 1
								matched = true
				
				if not matched:
					# Not a valid token: treat '<' as plain text and consume until next '<' or end
					var text_start: int = i
					var next_lt: int = input.find('<', i + 1)
					if next_lt == -1:
						next_lt = n
					var text: String = input.substr(text_start, next_lt - text_start)
					if text:
						# Process the text segment for links
						tokens.append_array(_process_text_segment(text))
					i = next_lt
			else:
				# Accumulate plain text until next '<' or end
				var text_start: int = i
				var next_lt: int = input.find('<', i)
				if next_lt == -1:
					next_lt = n
				var text: String = input.substr(text_start, next_lt - text_start)
				if text:
					# Process the text segment for links
					tokens.append_array(_process_text_segment(text))
				i = next_lt
		
		return tokens

	# Helper: find first occurrence of a character starting from `start`
	static func _find_char(s: String, c: String, start: int) -> int:
		for pos: int in range(start, s.length()):
			if s[pos] == c:
				return pos
		return -1

	# Helper: find the first non‑digit after a sequence of digits starting from `start`
	static func _find_id_end(s: String, start: int) -> int:
		var pos: int = start
		while pos < s.length() and s[pos].is_valid_int():
			pos += 1
		if pos > start and pos < s.length():
			return pos
		return -1

class TextToken extends Token:
	var text: String
	
	func _init(_text: String) -> void:
		super(Type.TEXT)
		self.text = _text

class LinkToken extends Token:
	var url: String
	
	func _init(_url: String) -> void:
		super(Type.LINK)
		self.url = _url

@abstract
class AbstractImageToken extends Token:
	var url: String
	
	func _init(_type: Type, _url: String) -> void:
		super(_type)
		
		self.url = _url

class EmojiToken extends AbstractImageToken:
	var emoji_name: String
	var emoji_id: String
	var animated: bool
	
	func _init(_emoji_name: String, _emoji_id: String, _animated: bool) -> void:
		super(Type.EMOJI, "%s/emojis/%s.%s?size=24" % [
			Discord.CDN_URL, _emoji_id, "gif" if _animated else "webp"
		])
		
		self.emoji_name = _emoji_name
		self.emoji_id = _emoji_id
		self.animated = _animated

class ImageToken extends AbstractImageToken:
	
	func _init(_url: String) -> void:
		super(Type.IMAGE, _url)

class ChannelToken extends Token:
	var channel_id: String
	
	func _init(_channel_id: String) -> void:
		super(Type.CHANNEL)
		
		self.channel_id = _channel_id

class UserToken extends Token:
	var user_id: String
	
	func _init(_user_id: String) -> void:
		super(Type.USER)
		
		self.user_id = _user_id
