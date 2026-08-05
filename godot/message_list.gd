extends Control
class_name UiMessageList

signal load_more_requested(direction: int, reference_message: Message)  # 1 for older (up), -1 for newer (down)
signal click_message(message: Message)

@export var avatar_size: float = 48
@export var avatar_margin: float = 8
@export var name_time_spacing: float = 4
@export var item_padding: float = 8

@export var normal_text_size: int = 14
@export var time_text_size: int = 12

@export var avatar_material: ShaderMaterial = ShaderMaterial.new()

@export var load_threshold: float = 100.0  # pixels from edge to trigger loading

@export_category("Colors")
@export var name_color: Color = Color.WHITE
@export var time_color: Color = Color.GRAY
@export var text_color: Color = Color(0.9, 0.9, 0.9)
@export var selection_color: Color = Color(0.3, 0.5, 0.8, 0.5)
@export var avatar_bg_color: Color = Color(0.2, 0.2, 0.3)
@export var avatar_text_color: Color = Color.WHITE

var _name_font: Font = ThemeDB.fallback_font
var _time_font: Font = ThemeDB.fallback_font
var _text_font: Font = ThemeDB.fallback_font

var _messages: Array[Message] = []

var _scroll_offset: float = 0.0:
	set(val):
		_scroll_offset = clamp(val, 0.0, max(0.0, self._total_content_height - self.size.y))
		_check_load_threshold()

var _total_content_height: float = 0.0

# Selection: Vector2i(message_index, character_index)
var _sel_start: Vector2i = Vector2i(-1, -1)
var _sel_end: Vector2i = Vector2i(-1, -1)

var _drag_message: int = -1 # message index being dragged
var _hover_message: int = -1  # message under mouse (for time display in grouped messages)

var _scrollable: bool = false

# mmm cache
var _layout_cache: Dictionary[int, TextParagraph] = {}
var _item_heights: Array[float] = []

var _message_rids: Dictionary[int, RID] = {}

func _init() -> void:
	self.focus_mode = Control.FOCUS_ALL
	self.mouse_default_cursor_shape = Control.CURSOR_IBEAM

func _ready() -> void:
	set_process_input(true)
	self.mouse_entered.connect(_mouse_entered)
	self.mouse_exited.connect(_mouse_exited)

func clear_messages() -> void:
	_messages.clear()
	_sel_start = Vector2i(-1, -1)
	_sel_end = Vector2i(-1, -1)
	_drag_message = -1
	_hover_message = -1

	_layout_cache.clear()
	_item_heights.clear()

	for rid in _message_rids.values():
		RenderingServer.free_rid(rid)

	_message_rids.clear()
	_scroll_offset = 0.0
	_total_content_height = 0.0

	queue_redraw()

func add_message(msg: Message) -> void:
	_messages.append(msg)
	var idx: int = _messages.size() - 1
	_layout_cache.erase(idx)
	_load_avatar(msg, idx)
	_update_total_height()
	queue_redraw()

func _load_avatar(msg: Message, msg_idx: int) -> void:
	var url = Discord.get_avatar_url(msg.author_id, msg.author_avatar, Discord.ceil_cdn_size(self.avatar_size))

	if Discord.image_cache.is_pending(url):
		return

	var texture = Discord.image_cache.get_cached(url)

	if texture:
		_create_message_rid(msg_idx, texture)
		queue_redraw()
		return

	texture = await Discord.image_cache.get_or_request(url, "webp")

	if not texture:
		return

	for i: int in _messages.size():
		if _messages[i].author_id == msg.author_id and not _message_rids.has(i):
			_create_message_rid(i, texture)

	queue_redraw()

func _create_message_rid(msg_idx: int, texture: Texture2D) -> void:
	var rid: RID = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(rid, get_canvas_item())
	RenderingServer.canvas_item_set_material(rid, self.avatar_material)
	
	var dest_rect: Rect2 = Rect2(0, 0, self.avatar_size, self.avatar_size)
	texture.draw_rect(rid, dest_rect, false)
	
	RenderingServer.canvas_item_set_visible(rid, false)
	_message_rids[msg_idx] = rid

func _input(event: InputEvent) -> void:
	if _scrollable:
		if event.is_action_released(&"ui_copy") and _sel_start.x != -1 and _sel_start.y != -1 and _sel_end.x != -1 and _sel_end.y != -1:
			var start = _sel_start
			var end = _sel_end
			# Normalize order (start <= end)
			if start.x > end.x or (start.x == end.x and start.y > end.y):
				var temp = start
				start = end
				end = temp
			var texts: Array[String] = []
			if start.x == end.x:
				texts.append(_messages[start.x].content.substr(start.y, end.y - start.y))
			else:
				# First message: from start.y to end
				texts.append(_messages[start.x].content.substr(start.y))
				# Middle messages: full content
				for i in range(start.x + 1, end.x):
					texts.append(_messages[i].content)
				# Last message: from 0 to end.y
				texts.append(_messages[end.x].content.substr(0, end.y))
			DisplayServer.clipboard_set("\n".join(texts))

		if event is InputEventPanGesture:
			_scroll_offset -= event.delta.y * 30
			queue_redraw()
			accept_event()
		elif event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_scroll_offset += event.factor * 30
				queue_redraw()
				accept_event()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_scroll_offset -= event.factor * 30
				queue_redraw()
				accept_event()

func _mouse_entered() -> void:
	_scrollable = true

func _mouse_exited() -> void:
	_scrollable = false
	_hover_message = -1
	queue_redraw()  # redraw to hide time on grouped messages

func _check_load_threshold() -> void:
	if _messages.is_empty():
		return

	var max_scroll = max(0.0, _total_content_height - size.y)

	if max_scroll == 0:
		return

	if _scroll_offset <= load_threshold:
		load_more_requested.emit(-1, _messages[-1])
	elif _scroll_offset >= max_scroll - load_threshold:
		load_more_requested.emit(1, _messages[0])

func _clamp_scroll() -> void:
	var max_scroll = max(0.0, _total_content_height - size.y)
	_scroll_offset = clamp(_scroll_offset, 0.0, max_scroll)

func _update_total_height() -> void:
	var total: float = 0.0

	_item_heights.clear()
	for i: int in _messages.size():
		var h: float = _compute_item_height(i)
		_item_heights.append(h)
		total += h
	_total_content_height = total

func _compute_item_height(msg_idx: int) -> float:
	if not _layout_cache.has(msg_idx):
		var target_width: float = size.x - self.item_padding * 2 - self.avatar_size - self.avatar_margin
		_update_layout_for_message(msg_idx, target_width)

	var paragraph: TextParagraph = _layout_cache[msg_idx]
	var text_height: float = paragraph.get_size().y
	var name_height: float = _name_font.get_height() if _name_font else 20.0

	var right_column_height: float = self.name_time_spacing + text_height
	var content_height: float = right_column_height

	if not _is_grouped(msg_idx):
		content_height = max(self.avatar_size, right_column_height + name_height)
	if _is_last_grouped(msg_idx):
		content_height += 2 * self.item_padding

	return content_height

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

	paragraph.add_string(msg.content, _text_font, self.normal_text_size)
	_layout_cache[msg_idx] = paragraph

func _update_layouts_if_needed() -> void:
	var target_width: float = size.x - self.item_padding * 2 - self.avatar_size - self.avatar_margin
	var needs_update: bool = false
	for i: int in _messages.size():
		if not _layout_cache.has(i):
			needs_update = true
			_update_layout_for_message(i, target_width)
		else:
			var para: TextParagraph = _layout_cache[i]
			if not is_equal_approx(para.width, target_width):
				needs_update = true
				_update_layout_for_message(i, target_width)
	if needs_update:
		_update_total_height()

func _is_grouped(msg_idx: int) -> bool:
	if msg_idx <= 0:
		return false
	var prev = _messages[msg_idx - 1]
	var cur = _messages[msg_idx]
	if cur.author_id != prev.author_id:
		return false
	var diff = abs(cur.timestamp - prev.timestamp)
	return diff <= 5 * 60  # 5 minutes in seconds

func _is_last_grouped(msg_idx: int) -> bool:
	if msg_idx + 1 >= len(_messages):
		return true
	var prev = _messages[msg_idx + 1]
	var cur = _messages[msg_idx]
	if cur.author_id != prev.author_id:
		return true
	var diff = abs(cur.timestamp - prev.timestamp)
	return diff > 5 * 60

func _draw() -> void:
	if _messages.is_empty():
		return

	_update_layouts_if_needed()

	var current_y: float = size.y + _scroll_offset

	for i: int in range(_messages.size() - 1, -1, -1):
		var item_height: float = _item_heights[i] if i < _item_heights.size() else _compute_item_height(i)
		var item_top: float = current_y - item_height
		current_y = item_top

		# Culling
		if item_top + item_height < 0 or item_top > size.y:
			if _message_rids.has(i):
				RenderingServer.canvas_item_set_visible(_message_rids[i], false)
			continue

		var msg: Message = _messages[i]
		var grouped: bool = _is_grouped(i)

		if not grouped:
			var avatar_rect: Rect2 = Rect2(
				self.item_padding, item_top + self.item_padding,
				self.avatar_size, self.avatar_size
			)

			if _message_rids.has(i):
				var rid: RID = _message_rids[i]
				RenderingServer.canvas_item_set_transform(rid, Transform2D(0, avatar_rect.position))
				RenderingServer.canvas_item_set_visible(rid, true)
			else:
				var center: Vector2 = avatar_rect.get_center()
				var radius: float = self.avatar_size / 2.0
				draw_circle(center, radius, avatar_bg_color)
				var initial: String = msg.author_name.substr(0, 1).to_upper()
				var font_size: int = int(radius * 0.8)
				var text_size: Vector2 = _name_font.get_string_size(initial)
				var text_pos: Vector2 = center - text_size / 2
				draw_string(_name_font, text_pos, initial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, avatar_text_color)
		else:
			if _message_rids.has(i):
				RenderingServer.canvas_item_set_visible(_message_rids[i], false)

		# Name & Time row
		var baseline_y: float = item_top + self.item_padding + _name_font.get_ascent()
		var time_x: float

		if not grouped:
			var name_str: String = msg.author_name
			var name_time_x: float = self.item_padding + self.avatar_size + self.avatar_margin
			draw_string(_name_font, Vector2(name_time_x, baseline_y), name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, self.normal_text_size, name_color)
			var name_width: float = _name_font.get_string_size(name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, self.normal_text_size).x
			time_x = name_time_x + name_width + self.item_padding
		else:
			time_x = self.item_padding

		# Draw time if not grouped, or if grouped and this message is hovered
		if not grouped or i == _hover_message:
			draw_string(_time_font, Vector2(time_x, baseline_y), Util.unix_to_human(msg.timestamp, grouped), HORIZONTAL_ALIGNMENT_CENTER, self.avatar_size if grouped else -1., self.time_text_size, time_color)

		# Message text
		var text_x: float = self.item_padding + self.avatar_size + self.avatar_margin
		var text_y: float = baseline_y
		if not grouped:
			text_y += self.name_time_spacing
		else:
			text_y -= self.normal_text_size
		var paragraph: TextParagraph = _layout_cache[i]

		# Selection rendering (multi‑message)
		if _sel_start.x != -1 and _sel_end.x != -1:
			var start = _sel_start
			var end = _sel_end
			if start.x > end.x or (start.x == end.x and start.y > end.y):
				var temp = start
				start = end
				end = temp
			var in_sel: bool = i >= start.x and i <= end.x
			if in_sel:
				var char_start: int = 0
				var char_end: int = len(msg.content)
				if start.x == end.x:
					char_start = start.y
					char_end = end.y
				elif i == start.x:
					char_start = start.y
					char_end = len(msg.content)
				elif i == end.x:
					char_start = 0
					char_end = end.y
				else:
					char_start = 0
					char_end = len(msg.content)
				if char_start != char_end and char_start >= 0 and char_end <= len(msg.content):
					var line_count: int = paragraph.get_line_count()
					var y_offset: float = 0.0
					for line: int in range(line_count):
						var line_range: Vector2i = paragraph.get_line_range(line)
						var line_start_char: int = line_range.x
						var line_end_char: int = line_range.y

						var overlap_start: int = max(char_start, line_start_char)
						var overlap_end: int = min(char_end, line_end_char)
						if overlap_start < overlap_end:
							var line_text: String = msg.content.substr(line_start_char, line_end_char - line_start_char)
							var prefix: String = line_text.substr(0, overlap_start - line_start_char)
							var selected: String = line_text.substr(overlap_start - line_start_char, overlap_end - overlap_start)

							var prefix_width: float = _text_font.get_string_size(prefix, HORIZONTAL_ALIGNMENT_LEFT, -1, self.normal_text_size).x
							var selected_width: float = _text_font.get_string_size(selected, HORIZONTAL_ALIGNMENT_LEFT, -1, self.normal_text_size).x

							var line_height: float = paragraph.get_line_ascent(line) + paragraph.get_line_descent(line)
							var line_rect: Rect2 = Rect2(
								prefix_width, y_offset,
								selected_width, line_height
							)
							draw_rect(Rect2(text_x + line_rect.position.x, text_y + line_rect.position.y, line_rect.size.x, line_rect.size.y), selection_color, true)

						y_offset += paragraph.get_line_ascent(line) + paragraph.get_line_descent(line)

		paragraph.draw(get_canvas_item(), Vector2(text_x, text_y))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var was_dragging = _drag_message != -1
				_drag_message = -1  # reset
				var mouse_pos: Vector2 = mb.position
				var msg_idx: int = _find_message_at_y(mouse_pos.y)
				if msg_idx >= 0:
					var char_idx: int = _get_character_index_at_pos(msg_idx, mouse_pos)
					if char_idx >= 0:
						if mb.shift_pressed and _sel_start.x != -1:
							# Extend selection
							_sel_end = Vector2i(msg_idx, char_idx)
						else:
							# Start new selection
							_sel_start = Vector2i(msg_idx, char_idx)
							_sel_end = _sel_start
						if not was_dragging:
							click_message.emit(_messages[msg_idx])
						_drag_message = msg_idx
						queue_redraw()
					else:
						# clicked in empty text area -> clear
						_sel_start = Vector2i(-1, -1)
						_sel_end = Vector2i(-1, -1)
						queue_redraw()
				else:
					# click outside messages -> clear
					_sel_start = Vector2i(-1, -1)
					_sel_end = Vector2i(-1, -1)
					queue_redraw()
			else:
				_drag_message = -1

	elif event is InputEventMouseMotion:
		# Update hover message (for time display on grouped messages)
		var new_hover = _find_message_at_y(event.position.y)
		if new_hover != _hover_message:
			_hover_message = new_hover
			queue_redraw()

		# Handle drag selection
		if _drag_message != -1:
			var current_msg: int = _find_message_at_y(event.position.y)
			if current_msg >= 0:
				_drag_message = current_msg
				var char_idx: int = _get_character_index_at_pos(current_msg, event.position)
				if char_idx >= 0 and _sel_start.x != -1:
					_sel_end = Vector2i(current_msg, char_idx)
					queue_redraw()

func _find_message_at_y(y_global: float) -> int:
	var current_y: float = size.y + _scroll_offset
	for i: int in range(_messages.size() - 1, -1, -1):
		var h: float = _item_heights[i] if i < _item_heights.size() else _compute_item_height(i)
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

	var item_y: float = _get_item_y(msg_idx)
	var grouped: bool = _is_grouped(msg_idx)
	var baseline_y: float = item_y + self.item_padding + _name_font.get_ascent()
	var text_y: float = baseline_y
	if not grouped:
		text_y += self.name_time_spacing
	else:
		text_y -= self.normal_text_size
	var text_x: float = self.item_padding + self.avatar_size + self.avatar_margin

	var local_pos: Vector2 = mouse_pos - Vector2(text_x, text_y)
	if local_pos.y < 0 or local_pos.y > paragraph.get_size().y:
		return -1

	var idx: int = paragraph.hit_test(local_pos)
	return idx if idx >= 0 else -1

func _get_item_y(msg_idx: int) -> float:
	var y: float = size.y + _scroll_offset
	for i: int in range(_messages.size() - 1, msg_idx, -1):
		y -= _item_heights[i] if i < _item_heights.size() else _compute_item_height(i)
	return y - (_item_heights[msg_idx] if msg_idx < _item_heights.size() else _compute_item_height(msg_idx))

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_cache.clear()
		_update_layouts_if_needed()
		queue_redraw()
