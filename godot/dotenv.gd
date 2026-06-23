extends Node

func _read_text(path: String) -> String:
	# Open the file in read mode
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if FileAccess.get_open_error() != OK:
			printerr("Could not open file: ", path, " Error code: ", FileAccess.get_open_error())
			return "" # Return an empty string or handle the error appropriately
		
		# Read the entire file as a single string
		return file.get_as_text()

func _ready() -> void:
	var lines: PackedStringArray = _read_text(".env").split("\n")
	
	var counter: int = 0
	for line: String in lines:
		counter += 1
		if line.strip_edges().is_empty(): continue
		if line.begins_with("#"): continue
		
		var comment_idx: int = line.find(" #")
		if comment_idx:
			line = line.substr(0, comment_idx)
		
		var parts: PackedStringArray = line.split("=", true, 1)
		
		if parts.size() != 2:
			print("Bad .env: line %s" % counter)
			continue
			
		OS.set_environment(parts[0], parts[1].strip_edges())
		print("Loaded '%s'" % parts[0])
