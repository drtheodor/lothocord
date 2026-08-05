var _http: HTTP
var _cache: Dictionary[String, Texture2D] = {}
var _pending: Dictionary[String, Future] = {}

## TODO: make imagecache more generalized, make a DiscordImageCache which would use ImageCache and wrap the ?size={x} parameter.
##   and wrap it to be a multiple of 16. Also pass preferred size, so it'd be something like DiscordImageCache.get_or_request("avatars/id/hash", 72) -> ImageCache.get_or_request("https://.../avatars/id/hash", 80) + Image.resize(72)

# Disk cache directory
const USE_ATLAS: bool = true

const CACHE_DIR: String = "user://cache/"
const DEFAULT_IMAGE: Texture2D = preload("res://icon.svg")

const ATLAS_SIZE = 1024

var atlas_img: Image
var atlas_texture: ImageTexture
var atlas_size: int = 0

func _init(http: HTTP) -> void:
	self._http = http
	
	# Create cache directory if it doesn't exist
	var err: Error = DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	if err != OK:
		push_error("Failed to create cache dir: ", err)
	
	if USE_ATLAS:
		self.atlas_img = Image.create_empty(ATLAS_SIZE, ATLAS_SIZE, false, Image.FORMAT_RGBA8)

func is_pending(url: String) -> bool:
	return _pending.has(url)

func _get_uv(idx: int, width: int) -> Vector2i:
	var capacity: int = (ATLAS_SIZE / width)^2

	var atlas_id = idx / capacity
	var u = idx / (ATLAS_SIZE / width)
	var v = idx % (ATLAS_SIZE / width)
	return Vector2i(u*width, v*width)

func _load_image(path: String, ext: String) -> Texture2D:
	if ext == "gif":
		push_warning("tried loading a gif")
		return null
	
	var image: Image = Image.new()
	var error: Error = image.load(path)
	
	if error != OK:
		push_error("Failed to parse image from ", path, ": ", error)
		return null
	
	if not USE_ATLAS:
		var texture: PortableCompressedTexture2D = PortableCompressedTexture2D.new()
		texture.create_from_image(image, PortableCompressedTexture2D.COMPRESSION_MODE_ASTC)
		return texture

	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)

	var uv = self._get_uv(self.atlas_size, image.get_width())
	self.atlas_img.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), uv)
	
	self.atlas_size += 1
	
	if self.atlas_texture:
		self.atlas_texture.update(self.atlas_img)
	else:
		self.atlas_texture = ImageTexture.create_from_image(self.atlas_img)
	
	var texture: AtlasTexture = AtlasTexture.new()
	texture.atlas = self.atlas_texture
	texture.filter_clip = true
	texture.region = Rect2i(uv, image.get_size())
	
	return texture

func get_cached(url: String) -> Texture2D:
	return _cache.get(url)

func get_or_request(url: String, ext: String) -> Texture2D:
	var result: Texture2D = self.get_cached(url)

	if result:
		return result
	else:
		# Check disk cache
		var cached_path: String = _get_cached_path(url, ext)

		if FileAccess.file_exists(cached_path):
			_cache[url] = null
			
			var texture: Texture2D = _load_image(cached_path, ext)
			
			if texture:
				_cache[url] = texture
				return texture
		
		return await request_image(url, ext).done

func request_image(url: String, ext: StringName) -> Future:
	if _pending.has(url):
		return _pending[url]

	# Start new download
	var result: Future = Future.new()
	_pending[url] = result
	
	_download_image(url, ext)
	return result

func _download_image(url: String, ext: StringName) -> void:
	print("Downloading ", url, " as ", ext)
	var resp: HTTP.Response = await self._http.request(url)

	if resp is HTTP.ResponseFail:
		push_error("Failed to start request for: ", url, ": ", resp.error)
		_cleanup_pending(url, null)
		return
	
	var texture: Texture2D = DEFAULT_IMAGE

	if resp is HTTP.ResponseSuccess:
		var success: HTTP.ResponseSuccess = resp
		
		var cache_path: String = _get_cached_path(url, ext)
		self._save_to_disk_cache(cache_path, ext, success.body)

		texture = _load_image(url, ext)
	
	_cache[url] = texture

	# Notify all callbacks
	_cleanup_pending(url, texture)

func _cleanup_pending(url: String, texture: Texture2D) -> void:
	var req: Future = _pending[url]

	if req:
		req.done.emit(texture)

	_pending.erase(url)

func _get_cached_path(url: String, ext: StringName) -> String:
	# Create a hash of the URL for filename
	var url_hash: String = str(url.md5_text())
	return CACHE_DIR + url_hash + "." + ext

func _save_to_disk_cache(url: String, ext: StringName, data: PackedByteArray) -> void:
	var cache_path: String = _get_cached_path(url, ext)
	var file: FileAccess = FileAccess.open(cache_path, FileAccess.WRITE)

	if file:
		file.store_buffer(data)
		file.close()

func clear_memory_cache() -> void:
	_cache.clear()

func clear_disk_cache() -> void:
	var dir: DirAccess = DirAccess.open(CACHE_DIR)

	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()

		while file_name != "":
			if not dir.current_is_dir():
				dir.remove(file_name)

			file_name = dir.get_next()

class Future:
	signal done(res: Variant)
