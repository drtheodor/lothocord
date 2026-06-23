class_name Util

const ZERO_RECT: Rect2 = Rect2()

static var EMOJI: RegEx = RegEx.create_from_string("<(a?):([A-Za-z0-9_]+):([0-9]+)>")

const IMAGES: Array[String] = [
	"png", "jpg", "jpeg", "webp", "gif"
];

func extract_emoji_url(raw: String) -> String:
	var match: RegExMatch = EMOJI.search(raw)
	
	if not match:
		return "" # TODO: return null instead
	
	var animated: bool = match.get_string(1) == "a"
	var id: String = match.get_string(3)
	
	return "%s/emojis/%s.%s?size=64&quality=lossless" % [Discord.CDN_URL, id, "gif" if animated else "webp"]

static func json_s2i(json: Dictionary, path: String, default: int = -1) -> int:
	var some: Variant = json.get(path, default)
	
	if some is int:
		return some
	
	if some is String:
		var ssome: String = some
		return int(ssome)
	
	return default

static func get_time_millis() -> int:
	return int(Time.get_unix_time_from_system() * 1000)

static func unix_to_human(timestamp: int) -> String:
	var timezone_info: Dictionary = Time.get_time_zone_from_system()
	var utc_offset_minutes: int = timezone_info["bias"]
	var unix_timestamp_local: int = timestamp + (utc_offset_minutes * 60)
	var local: Dictionary = Time.get_datetime_dict_from_unix_time(unix_timestamp_local)
	var now: Dictionary = Time.get_datetime_dict_from_system()
	
	var text: String = "%02d:%02d" % [local["hour"], local["minute"]]
	if now["day"] - 1 == local["day"] and local["month"] == now["month"] and local["year"] == now["year"]:
		text = "Yesterday, %s" % text
	elif local["day"] != now["day"] or local["month"] != now["month"] or local["year"] != now["year"]:
		text = "%02d/%02d/%04d, %s" % [local["day"], local["month"], local["year"], text]
	return text

static var URL_REGEX: RegEx = RegEx.create_from_string("https?://[^\\s<>]+|www\\.[^\\s<>]+")

## Returns the extension of the url
static func url_extension(url: String) -> String:
	var ext: String = url.get_extension()
	var query: int = ext.find("?")
	
	if query:
		ext = ext.substr(0, query)
	
	return ext.to_lower()

static func is_image(url: String) -> bool:
	var ext: String = Util.url_extension(url)
	
	for image: String in Util.IMAGES:
		if ext == image:
			return true
	
	return false

## UUID v4 stuff
## Original: https://github.com/binogure-studio/godot-uuid/blob/master/addons/uuid/uuid.gd
## License: MIT
## Changes: 
##  - improved typing

const BYTE_MASK: int = 0b11111111

static func _uuidbin() -> Array[int]:
	# 16 random bytes with the bytes on index 6 and 8 modified
	return [
		randi() & BYTE_MASK, randi() & BYTE_MASK, randi() & BYTE_MASK, randi() & BYTE_MASK,
		randi() & BYTE_MASK, randi() & BYTE_MASK, ((randi() & BYTE_MASK) & 0x0f) | 0x40, randi() & BYTE_MASK,
		((randi() & BYTE_MASK) & 0x3f) | 0x80, randi() & BYTE_MASK, randi() & BYTE_MASK, randi() & BYTE_MASK,
		randi() & BYTE_MASK, randi() & BYTE_MASK, randi() & BYTE_MASK, randi() & BYTE_MASK,
	]

static func uuid_v4() -> String:
	# 16 random bytes with the bytes on index 6 and 8 modified
	var b: Array[int] = _uuidbin()

	return '%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x' % [
		# low
		b[0], b[1], b[2], b[3],

		# mid
		b[4], b[5],

		# hi
		b[6], b[7],

		# clock
		b[8], b[9],

		# clock
		b[10], b[11], b[12], b[13], b[14], b[15]
	]
