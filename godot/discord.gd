# FIXME: `Discord` shouldn't be *the* global API wrapper thingy
extends Node

const WEBSOCKET_URL: String = "wss://gateway.discord.gg/?encoding=json&v=9&compress=zlib-stream"
const CDN_URL: String = "https://cdn.discordapp.com"
const BASE_URL: String = "https://discord.com/api/v9"

const GATEWAY_POLL_DELAY: int = 250 # in ms

const MASQUERADE_OS: String = "Linux"
const MASQUERADE_LOCALE: String = "en-US"

const MASQUERADE_BROWSER: String = "Chrome"
const MASQUERADE_BROWSER_VERSION: String = "144.0.0.0"
static var MASQUERADE_BROWSER_AGENT: String = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) %s/%s Safari/537.36" % [MASQUERADE_BROWSER, MASQUERADE_BROWSER_VERSION]

const MASQUERADE_DISCORD_CHANNEL: String = "stable"
const MASQUERADE_DISCORD_BUILD: int = 498386

const ImageCache: GDScript = preload("res://image_cache.gd")
const Gateway: GDScript = preload("res://gateway.gd")

static var DEFAULT_HEADERS: PackedStringArray = PackedStringArray([
	"Authorization: " + token,
	"User-Agent: " + MASQUERADE_BROWSER_AGENT,
])

var http: HTTP = HTTP.new()
var _gateway: Gateway = Gateway.new()
var _heartbeat_interval: int
var _last_heartbeat: int = -1

var guild_cache: Dictionary[String, Guild] = {}
var channel_cache: Dictionary[String, Channel] = {}
#var message_cache: Dictionary[String, Message] = {}

var image_cache: ImageCache = ImageCache.new(http)

signal on_ready()
signal on_message(message: Message)
signal on_typing(user: User)

func _ready() -> void:
	self.add_child(self.http)
	
	self._gateway.on_connected.connect(self._on_gateway_connected)
	self._gateway.on_message.connect(self._on_gateway_message)
	self._gateway.on_close.connect(self._on_gateway_close)
	
	var err: Error = self._gateway.connect_to_url(WEBSOCKET_URL)
	
	if err == OK:
		print("Connecting to Discord Gateway")
	else:
		push_error("Failed to connect to Discord Gateway: ", err)
	
	var poll_timer: Timer = Timer.new()
	poll_timer.autostart = true
	poll_timer.one_shot = false
	poll_timer.wait_time = float(GATEWAY_POLL_DELAY) / 1000
	poll_timer.timeout.connect(self._gateway.poll)
	
	self.add_child(poll_timer)
	
	#self.on_message.connect(self._on_message)

#func _on_message(message: Message) -> void:
#	self.message_cache[message.message_id] = message

func _on_gateway_connected(socket: WebSocketPeer) -> void:
	print("> Sending handshake packet.")
			
	socket.send_text(JSON.stringify({
		"op": 2, # Identity
		"d": {
			"token": self.token,
			"capabilities": 1734653, # whatever that is
			"properties": {
				"os": MASQUERADE_OS,
				"browser": MASQUERADE_BROWSER,
				"device": "",
				"system_locale": MASQUERADE_LOCALE,
				"has_client_mods": false, # client mods? i hardly know 'er!
				"browser_user_agent": MASQUERADE_BROWSER_AGENT,
				"browser_version": MASQUERADE_BROWSER_VERSION,
				"os_version": "",
				"referrer": "",
				"referring_domain": "",
				"referrer_current": "",
				"referring_domain_current": "",
				"release_channel": MASQUERADE_DISCORD_CHANNEL,
				"client_build_number": MASQUERADE_DISCORD_BUILD,
				"client_event_source": null,
				"client_launch_id": Util.uuid_v4(),
				"is_fast_connect": true
			},
			"client_state": {
				"guild_versions": {}
			}
		}
	}))

func _on_gateway_close(_socket: WebSocketPeer, code: int, reason: String) -> void:
	print("WebSocket closed with code: %d. Clean: %s; %s" % [code, code != -1, reason])
	
func _on_gateway_message(socket: WebSocketPeer, some_json: Variant) -> void:
	if self._heartbeat_interval and Util.get_time_millis() - self._last_heartbeat > self._heartbeat_interval:
		if OS.is_debug_build():
			print("Heartbeat")
		
		socket.send_text(JSON.stringify({
			"op": 40,
			"d": {
				"seq": self._gateway.seq,
				"qos": {
					"active": false,
					"ver": 27,
					"reasons": []
				}
			}
		}))
		self._last_heartbeat = Util.get_time_millis()
	
	if not some_json or some_json is not Dictionary:
		push_error("Received malformed JSON from gateway", some_json)
	else:
		var json: Dictionary = some_json
		match json["t"]:
			"READY":
				var some_data: Variant = json["d"]
				
				var _user: Dictionary = some_data["user"]
				self.user = User.from_json(_user)
				
				var _guilds: Array = some_data["guilds"]
				# roles, stickers, threads, channels, 
				# properties { name, icon, banner }, 
				# member_count, large, emojis
				for raw_guild: Dictionary in _guilds:
					var guild: Guild = Guild.from_json(raw_guild)
					self.guild_cache[guild.guild_id] = guild
				
					for guild_channel: Channel in guild.channels:
						self.channel_cache[guild_channel.channel_id] = guild_channel
				
				self.on_ready.emit()
				
				var _private_channels: Array = some_data["private_channels"]
				var _users: Array = some_data["users"]
				
				var all_session: Variant = some_data["sessions"][0]
				
				socket.send_text(JSON.stringify({
					"op": 3, # Presence Update
					"d": {
						"status": "unknown",
						"since": 0,
						"activities": [],
						"afk": false
					}
				}))
				
				socket.send_text(JSON.stringify({
					"op": 4, # Voice State Update
					"d": {
						"guild_id": null,
						"channel_id": null,
						"self_mute": false, 
						"self_deaf": false,
						"self_video": false,
						"flags": 2
					}
				}))
				
				# set_watching_channel
				#{"op":13,"d":{"channel_id":"1262635952283582484"}}
				
				socket.send_text(JSON.stringify({
					"op": 3, # Presence Update
					"d": {
						"status": all_session["status"],
						"since": 0,
						"activities": all_session["activities"],
						"afk": false
					}
				}))
				
				socket.send_text(JSON.stringify({
					"op": 41,
					"d": {
						"initialization_timestamp": Util.get_time_millis(),
						"session_id": Util.uuid_v4(),
						"client_launch_id": Util.uuid_v4()
					}
				}))
			
			"TYPING_START":
				var some_data: Variant = json["d"]
				
				if not some_data or some_data is not Dictionary:
					push_error("'TYPING_START' event is invalid: ", some_data)
					return
				
				var message_json: Dictionary = some_data
				var channel_id: String = message_json["channel_id"]
				
				if channel_id == self.channel and "member" in message_json:
					var typing_user: Dictionary = message_json["member"]["user"]
					self.on_typing.emit(User.from_json(typing_user))
			
			"MESSAGE_CREATE":
				var some_data: Variant = json["d"]
				
				if not some_data or some_data is not Dictionary:
					push_error("'MESSAGE_CREATE' event is invalid: ", some_data)
					return
				
				var message_json: Dictionary = some_data
				if message_json["channel_id"] == self.channel:
					self.on_message.emit(Message.from_json(message_json))
			_:
				@warning_ignore("unsafe_call_argument")
				if not self._heartbeat_interval and int(json["op"]) == 10: # HELLO
					self._heartbeat_interval = json["d"]["heartbeat_interval"]
					print("Heartbeat Interval: ", self._heartbeat_interval)
					return
				
				if OS.is_debug_build():
					print("Unhandled event ", json["t"])

func get_avatar_url(user_id: String, avatar_id: String, size: int = 64) -> String:
	# TODO: automatically change size to be 16, 32, 48, 64, 80, ..., 128, 
	return "%s/avatars/%s/%s.webp?size=%s" % [CDN_URL, user_id, avatar_id, size]

func get_avatar(user_id: String, avatar_id: String, size: int = 64) -> ImageTexture:
	if not avatar_id: return null
	
	var url: String = self.get_avatar_url(user_id, avatar_id, size)
	return await self.image_cache.get_or_request(url, "webp")

func get_guild_icon(guild_id: String, guild_avatar: String, size: int = 64) -> ImageTexture:
	if not guild_avatar: return null
	
	var url: String = "%s/icons/%s/%s.webp?size=%s" % [CDN_URL, guild_id, guild_avatar, size]
	return await self.image_cache.get_or_request(url, "webp")

func fetch_messages(channel_id: String) -> Array[Message]:
	var url: String = "%s/channels/%s/messages" % [BASE_URL, channel_id]
	var data: Variant = await Discord.http.request_json_or_null(url, ["Authorization: " + Discord.token])
	
	if not data or data is not Array:
		return [Message.system_message("Failed to load messages")]
	
	var messages: Array = data
	var result: Array[Message] = []
	
	for raw_message: Variant in messages:
		var message_dict: Dictionary = raw_message
		result.append(Message.from_json(message_dict))
	
	return result

func get_channel(channel_id: String) -> Channel:
	var res: Channel = self.channel_cache.get(channel_id)
	
	if res: return res
	
	var url: String = "%s/channels/%s" % [BASE_URL, channel_id]
	var data: Variant = await http.request_json_or_null(url, ["Authorization: " + token])
	
	if data is Dictionary:
		var dict: Dictionary = data
		return Channel.from_json(dict)
	
	return null

func send_message(channel_id: String, message: String, replying_to: String = "") -> int:
	var s: int = self._generate_snowflake()
	
	var body: Dictionary[String, Variant] = {
		# No clue what that is
		"mobile_network_type": "unknown", 
		"content": message,
		
		# Used to verify message consistency, we don't know the message id when we send it, but we do know the nonce...
		"nonce": str(s), 
		"tts": false,
		"flags": 0
	}
	
	if replying_to:
		body["allowed_mentions"] = {
			"parse": ["users", "roles", "everyone"],
			"replied_user": false
		}
		
		body["message_reference"] = {
			"message_id": replying_to
		}
	
	var url: String = "%s/channels/%s/messages" % [BASE_URL, channel_id]
	
	http.request(url, [
		"Authorization: " + self.token, 
		"Content-Type: application/json"
	], HTTPClient.Method.METHOD_POST, JSON.stringify(body))
	
	return s

const DISCORD_EPOCH: int = 1420070400000

# Used in snowflake generation
const WORKER_ID: int = 1
const PROCESS_ID: int = 1

# How many snowflakes were generated
var _snowflakes: int = 0

# https://docs.discord.com/developers/reference#snowflakes
func _generate_snowflake() -> int:
	var cur_time: int = Util.get_time_millis()
	var res: int = int(cur_time - DISCORD_EPOCH) << 22
	
	res += WORKER_ID << 17
	res += PROCESS_ID << 12
	res += _snowflakes
	
	_snowflakes += 1
	return res

func follow_guild(guild_id: String) -> void:
	self._gateway.socket.send_text(JSON.stringify({
		"op": 36,
		"d": {
			"guild_id": guild_id
		}
	}))
	
	var whatever: String = JSON.stringify({
		"op": 43,
		"d": {
			"guild_id": guild_id,
			"fields": ["status", "voice_start_time"]
		}
	})
	
	# why? no idea!
	for i: int in range(3):
		self._gateway.socket.send_text(whatever)
	
	self._gateway.socket.send_text(JSON.stringify({
		"op": 37,
		"d": {
			"subscriptions": {
				guild_id: {
					"typing": true,
					"activities": true,
					"threads": true
				}
			}
		}
	}))

func mark_as_read(channel_id: String, message_id: String) -> void:
	var url: String = "%s/channels/%s/messages/%s/ack" % [BASE_URL, channel_id, message_id]
	self.http.request(url, ["Authorization: " + Discord.token], HTTPClient.METHOD_POST, JSON.stringify({"last_viewed": 4077, "token": null}))

static var token: String:
	get:
		return OS.get_environment("TOKEN")

var user: User

var channel: String:
	set(val):
		channel = val
		
		self._gateway.socket.send_text(JSON.stringify({
			"op": 13,
			"d": {
				"channel_id": val
			}
		}))
		
