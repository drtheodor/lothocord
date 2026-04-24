extends Control
class_name MessageList

const AVATAR_SIZE: float = 48
const AVATAR_MARGIN: float = 8
const NAME_TIME_SPACING: float = 8
const ITEM_PADDING: float = 8

const NORMAL_TEXT_SIZE: int = 14
const TIME_TEXT_SIZE: int = 12

# Colors
const BG_COLOR: Color = Color(0.1, 0.1, 0.12)
const NAME_COLOR: Color = Color.WHITE
const TIME_COLOR: Color = Color.GRAY
const TEXT_COLOR: Color = Color(0.9, 0.9, 0.9)
const SELECTION_COLOR: Color = Color(0.3, 0.5, 0.8, 0.5)
const AVATAR_BG_COLOR: Color = Color(0.2, 0.2, 0.3)
const AVATAR_TEXT_COLOR: Color = Color.WHITE

# Fonts
var _name_font: Font
var _time_font: Font
var _text_font: Font

# Data
var _messages: Array[Message] = []
var _scroll_offset: float = 0.0
var _total_content_height: float = 0.0

var _sel_start: Dictionary[int, int] = {}
var _sel_end: Dictionary[int, int] = {}
var _is_selecting: bool = false
var _last_click_message: int = -1

var _scrollable: bool = false

# Cache for per-message TextParagraph
var _layout_cache: Dictionary[int, TextParagraph] = {}

# ------------------------------------------------------------------------------
func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_IBEAM

func _ready() -> void:
	_name_font = ThemeDB.fallback_font
	_time_font = ThemeDB.fallback_font
	_text_font = ThemeDB.fallback_font
	set_process_input(true)
	
	self.mouse_entered.connect(_mouse_entered)
	self.mouse_exited.connect(_mouse_exited)

# ------------------------------------------------------------------------------
# Public API
# ------------------------------------------------------------------------------
func clear_messages() -> void:
	_messages.clear()
	_sel_start.clear()
	_sel_end.clear()
	_layout_cache.clear()
	_scroll_offset = 0.0
	_total_content_height = 0.0
	queue_redraw()

func add_message(msg: Message) -> void:
	_messages.append(msg)
	var idx: int = _messages.size() - 1
	_sel_start[idx] = -1
	_sel_end[idx] = -1
	_layout_cache.erase(idx)
	_update_layout_for_message(idx, size.x)
	_update_total_height()
	queue_redraw()

# Scrolling
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and _scrollable:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_offset += event.factor * 30   # scroll up -> move view up
			_clamp_scroll()
			queue_redraw()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_offset -= event.factor * 30   # scroll down -> move view down
			_clamp_scroll()
			queue_redraw()
			accept_event()

func _mouse_entered() -> void:
	_scrollable = true

func _mouse_exited() -> void:
	_scrollable = false

func _clamp_scroll() -> void:
	var max_scroll: float = max(0.0, _total_content_height - size.y)
	_scroll_offset = clamp(_scroll_offset, 0.0, max_scroll)

func _update_total_height() -> void:
	var total: float = 0.0
	for i: int in _messages.size():
		total += _get_item_height(i)
	_total_content_height = total
	_clamp_scroll()

func _get_item_height(msg_idx: int) -> float:
	if not _layout_cache.has(msg_idx):
		return 100.0
	
	var paragraph: TextParagraph = _layout_cache[msg_idx]
	var text_height: float = paragraph.get_size().y
	var name_height: float = _name_font.get_height() if _name_font else 20.0
	
	var right_column_height: float = name_height + NAME_TIME_SPACING + text_height
	var content_height: float = max(AVATAR_SIZE, right_column_height)
	return ITEM_PADDING * 2 + content_height

func _update_layout_for_message(msg_idx: int, target_width: float) -> void:
	if msg_idx < 0 or msg_idx >= _messages.size():
		return
	
	var msg: Message = _messages[msg_idx] 
	
	var paragraph: TextParagraph = TextParagraph.new()
	paragraph.orientation = TextServer.ORIENTATION_HORIZONTAL
	paragraph.direction = TextServer.DIRECTION_AUTO
	paragraph.width = target_width
	paragraph.justification_flags = TextServer.JUSTIFICATION_NONE
	paragraph.alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	paragraph.add_string(msg.content(), _text_font, NORMAL_TEXT_SIZE)
	
	_layout_cache[msg_idx] = paragraph

func _update_layouts_if_needed() -> void:
	var target_width: float = size.x - ITEM_PADDING * 2 - AVATAR_SIZE - AVATAR_MARGIN
	for i: int in _messages.size():
		if not _layout_cache.has(i):
			_update_layout_for_message(i, target_width)
		else:
			var para: TextParagraph = _layout_cache[i]
			if not is_equal_approx(para.width, target_width):
				_update_layout_for_message(i, target_width)

static func _unix_to_human(timestamp: int) -> String:
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

func _draw() -> void:
	if _messages.is_empty():
		return
	
	_update_layouts_if_needed()
	
	var current_y: float = size.y + _scroll_offset
	
	for i: int in range(_messages.size() - 1, -1, -1):
		var msg: Message = _messages[i]
		var item_height: float = _get_item_height(i)
		var item_top: float = current_y - item_height
		var item_rect: Rect2 = Rect2(0, item_top, size.x, item_height)
		
		if item_top + item_height < 0 or item_top > size.y:
			current_y = item_top
			continue
		
		var bg: Color = BG_COLOR.darkened(0.2) if i % 2 == 0 else BG_COLOR
		draw_rect(item_rect, bg, true)
		
		var avatar_rect: Rect2 = Rect2(
			ITEM_PADDING, item_top + ITEM_PADDING,
			AVATAR_SIZE, AVATAR_SIZE
		)
		if msg.author_avatar:
			draw_texture_rect(await Discord.get_avatar(msg.author_id, msg.author_avatar), avatar_rect, false)
		else:
			var center: Vector2 = avatar_rect.get_center()
			var radius: float = AVATAR_SIZE / 2.0
			draw_circle(center, radius, AVATAR_BG_COLOR)
			var initial: String = msg.author_name.substr(0, 1).to_upper()
			var font_size: int = int(radius * 0.8)
			var text_size: Vector2 = _name_font.get_string_size(initial)
			var text_pos: Vector2 = center - text_size / 2
			draw_string(_name_font, text_pos, initial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, AVATAR_TEXT_COLOR)
		
		# --- Name + Time row -------------------------------------------------
		var name_time_x: float = avatar_rect.position.x + AVATAR_SIZE + AVATAR_MARGIN
		var name_time_y: float = item_top + ITEM_PADDING
		
		if _name_font:
			draw_string(_name_font, Vector2(name_time_x, name_time_y + _name_font.get_ascent()), msg.author_name, HORIZONTAL_ALIGNMENT_LEFT, -1, NORMAL_TEXT_SIZE, NAME_COLOR)
		
		var time_str: String = _unix_to_human(msg.timestamp)
		if _time_font:
			var time_width: float = _time_font.get_string_size(time_str).x
			var time_x: float = size.x - time_width - ITEM_PADDING
			draw_string(_time_font, Vector2(time_x, name_time_y + _time_font.get_ascent()), time_str, HORIZONTAL_ALIGNMENT_LEFT, -1, TIME_TEXT_SIZE, TIME_COLOR)
		
		# --- Message text area ----------------------------------------------
		var text_x: float = name_time_x
		var name_height: float = _name_font.get_height() if _name_font else 20.0
		var text_y: float = name_time_y + name_height + NAME_TIME_SPACING
		var paragraph: TextParagraph = _layout_cache[i]
		
		# Draw selection
		var sel_start: int = _sel_start.get(i, -1)
		var sel_end: int = _sel_end.get(i, -1)
		if sel_start != -1 and sel_end != -1 and sel_start != sel_end:
			# Work with a normalised selection (start <= end)
			var start_idx: int = min(sel_start, sel_end)
			var end_idx: int = max(sel_start, sel_end)
			
			var line_count: int = paragraph.get_line_count()
			var y_offset: float = 0.0
			for line: int in range(line_count):
				var line_range: Vector2i = paragraph.get_line_range(line)
				var line_start_char: int = line_range.x
				var line_end_char: int = line_range.y
				
				# Intersection between selection and this line
				var overlap_start: int = max(start_idx, line_start_char)
				var overlap_end: int = min(end_idx, line_end_char)
				if overlap_start < overlap_end:
					# Extract the substring for this line from the original message content
					var line_text: String = msg.content().substr(line_start_char, line_end_char - line_start_char)
					
					# Prefix part (before the selection) and the selected part
					var prefix: String = line_text.substr(0, overlap_start - line_start_char)
					var selected: String = line_text.substr(overlap_start - line_start_char, overlap_end - overlap_start)
					
					# Measure widths
					var prefix_width: float = _text_font.get_string_size(prefix).x
					var selected_width: float = _text_font.get_string_size(selected).x
					
					# Line dimensions (using the available line metrics)
					var line_height: float = paragraph.get_line_ascent(line) + paragraph.get_line_descent(line)
					var line_rect: Rect2 = Rect2(
						prefix_width, y_offset,
						selected_width, line_height
					)
					
					# Draw the selection rectangle
					draw_rect(Rect2(text_x + line_rect.position.x, text_y + line_rect.position.y, line_rect.size.x, line_rect.size.y), SELECTION_COLOR, true)
				
				# Update vertical position for the next line
				y_offset += paragraph.get_line_ascent(line) + paragraph.get_line_descent(line)
		
		# Draw the paragraph itself
		paragraph.draw(get_canvas_item(), Vector2(text_x, text_y))
		
		# Move upward for the next (older) message
		current_y = item_top

# Mouse selection handling
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_is_selecting = true
				_last_click_message = -1
				var mouse_pos: Vector2 = mb.position
				var msg_idx: int = _find_message_at_y(mouse_pos.y)
				if msg_idx >= 0:
					_last_click_message = msg_idx
					var char_idx: int = _get_character_index_at_pos(msg_idx, mouse_pos)
					if char_idx >= 0:
						_sel_start[msg_idx] = char_idx
						_sel_end[msg_idx] = char_idx
					else:
						_sel_start[msg_idx] = -1
						_sel_end[msg_idx] = -1
					# Clear other selections
					for k: int in _sel_start.keys():
						if k != msg_idx:
							_sel_start[k] = -1
							_sel_end[k] = -1
					queue_redraw()
				else:
					# Click outside -> clear all selections
					for k: int in _sel_start.keys():
						_sel_start[k] = -1
						_sel_end[k] = -1
					queue_redraw()
			else:
				_is_selecting = false
				_last_click_message = -1
	
	elif event is InputEventMouseMotion and _is_selecting:
		var mm: InputEventMouseMotion = event
		if _last_click_message >= 0 and _last_click_message < _messages.size():
			var char_idx: int = _get_character_index_at_pos(_last_click_message, mm.position)
			if char_idx >= 0:
				var start: int = _sel_start[_last_click_message]
				if start != -1:
					_sel_end[_last_click_message] = char_idx
					queue_redraw()

func _find_message_at_y(y_global: float) -> int:
	var current_y: float = size.y + _scroll_offset
	for i: int in range(_messages.size() - 1, -1, -1):
		var h: float = _get_item_height(i)
		var item_top: float = current_y - h
		if y_global >= item_top and y_global < item_top + h:
			return i
		current_y = item_top
	return -1

func _get_character_index_at_pos(msg_idx: int, mouse_pos: Vector2) -> int:
	if msg_idx < 0 or msg_idx >= _messages.size():
		return -1
	var paragraph: TextParagraph = _layout_cache.get(msg_idx)
	if not paragraph:
		return -1
	
	# Compute global position of the message's text area
	var item_y: float = _get_item_y(msg_idx)
	var name_time_y: float = item_y + ITEM_PADDING
	var name_height: float = _name_font.get_height() if _name_font else 20.0
	var text_y: float = name_time_y + name_height + NAME_TIME_SPACING
	var text_x: float = ITEM_PADDING + AVATAR_SIZE + AVATAR_MARGIN
	
	var local_pos: Vector2 = mouse_pos - Vector2(text_x, text_y)
	if local_pos.y < 0 or local_pos.y > paragraph.get_size().y:
		return -1
	
	var idx: int = paragraph.hit_test(local_pos)
	return idx if idx >= 0 else -1

func _get_item_y(msg_idx: int) -> float:
	var y: float = size.y + _scroll_offset
	for i: int in range(_messages.size() - 1, msg_idx, -1):
		y -= _get_item_height(i)
	return y - _get_item_height(msg_idx)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_cache.clear()
		_update_layouts_if_needed()
		_update_total_height()
		queue_redraw()
