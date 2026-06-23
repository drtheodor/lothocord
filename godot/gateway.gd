static var ZLIB_SUFFIX: PackedByteArray = PackedByteArray(
	[0x00, 0x00, 0xff, 0xff]
)  # as an array for easy comparison

const OUTBOUND_BUFFER_SIZE: int = 10 * 1024 * 1024 # 10MBs TODO: find smaller limit
const INBOUND_BUFFER_SIZE: int = 10 * 1024 * 1024 # 10MBs TODO: find smaller limit

var socket: WebSocketPeer = WebSocketPeer.new()
var decompressor: ZlibDecompressor = ZlibDecompressor.new()

var buffer: PackedByteArray = PackedByteArray()
var seq: int

enum State {
	DEAD,
	CONNECTING,
	CONNECTED,
}

var _state: State = State.DEAD

signal on_connected(socket: WebSocketPeer)
signal on_message(socket: WebSocketPeer, data: String)
signal on_close(socket: WebSocketPeer, code: int, reason: String)

func _init() -> void:
	socket.outbound_buffer_size = OUTBOUND_BUFFER_SIZE
	socket.inbound_buffer_size = INBOUND_BUFFER_SIZE

func connect_to_url(url: String) -> Error:
	decompressor.start_decompression()
	var err: Error = socket.connect_to_url(url)
	
	if err == OK:
		self._state = State.CONNECTING
	
	return err

func poll() -> Error:
	if self._state == State.DEAD: return ERR_UNCONFIGURED
	
	socket.poll()
	
	# get_ready_state() tells you what state the socket is in.
	var state: WebSocketPeer.State = socket.get_ready_state()

	# `WebSocketPeer.STATE_OPEN` means the socket is connected and ready
	# to send and receive data.
	if state == WebSocketPeer.STATE_OPEN:
		if self._state == State.CONNECTING:
			self.on_connected.emit(socket)
			self._state = State.CONNECTED
		while socket.get_available_packet_count():
			var packet: PackedByteArray = socket.get_packet()
			if socket.was_string_packet():
				var packet_text: String = packet.get_string_from_utf8()
				self.on_message.emit(packet_text)
			else:
				buffer.append_array(packet)
				
				# Check for flush suffix
				if buffer.size() >= 4 and buffer.slice(buffer.size() - 4) == ZLIB_SUFFIX:
					# Feed the entire buffer into the decompressor
					var err: Error = decompressor.feed_data(packet)
					
					if err != OK:
						push_error("feed_data failed: ", err)
						buffer.clear()
						return err
					
					# Read the decompressed message
					var decompressed: PackedByteArray = decompressor.read_decompressed()
					var message_text: String = decompressed.get_string_from_utf8()
					
					if message_text:
						var data: Variant = JSON.parse_string(message_text)
						
						if data:
							var _seq: Variant = data.get("s")
							
							if _seq:
								self.seq = _seq
						
						self.on_message.emit(socket, data)
						
					buffer.clear()
				
	# `WebSocketPeer.STATE_CLOSING` means the socket is closing.
	# It is important to keep polling for a clean close.
	elif state == WebSocketPeer.STATE_CLOSING:
		pass
	elif state == WebSocketPeer.STATE_CLOSED:
		# The code will be `-1` if the disconnection was not properly notified by the remote peer.
		var code: int = socket.get_close_code()
		
		self.on_close.emit(socket, code, socket.get_close_reason())
		self._state = State.DEAD
	
	return OK
