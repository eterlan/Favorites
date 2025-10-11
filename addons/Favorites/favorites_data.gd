@tool
extends RefCounted
class_name FavoritesData

const FAVORITES_FILE = "user://favorites.json"

var favorites: Array = []
var debug_enabled: bool = true
var settings: Dictionary = {
	"auto_switch_to_script": false,
	"auto_switch_to_scene": false,
	"debug_enabled": true
}

# Debug print method - only prints when debug is enabled
func debug_print(message: String):
	if debug_enabled:
		print("[Favorites Debug] ", message)

# Enable/disable debug mode
func set_debug_enabled(enabled: bool):
	debug_enabled = enabled
	debug_print("Debug mode " + ("enabled" if enabled else "disabled"))

func add_favorite(favorite: Dictionary) -> bool:
	# Check if the same favorite item already exists
	if is_favorited(favorite):
		debug_print("Item already exists: " + favorite.name)
		return false
	
	favorites.append(favorite)
	save_favorites()
	debug_print("Added favorite: " + favorite.name)
	return true

func remove_favorite(index: int):
	if index >= 0 and index < favorites.size():
		var favorite = favorites[index]
		favorites.remove_at(index)
		save_favorites()
		debug_print("Removed favorite: " + favorite.name)

func get_favorites() -> Array:
	return favorites

func get_favorite_by_index(index: int) -> Dictionary:
	if index >= 0 and index < favorites.size():
		return favorites[index]
	return {}

# Check if two favorites are the same (unified comparison logic)
func _favorites_match(fav1: Dictionary, fav2: Dictionary) -> bool:
	return fav1.path == fav2.path and fav1.get("node_path", "") == fav2.get("node_path", "")

# Check if already favorited
func is_favorited(favorite: Dictionary) -> bool:
	return find_favorite_index(favorite) != -1

# Overloaded version for path-based check
func is_favorited_by_path(path: String, node_path: String = "") -> bool:
	var temp_favorite = {"path": path, "node_path": node_path}
	return is_favorited(temp_favorite)

func find_favorite_index_by_path(path: String, node_path: String = "") -> int:
	var temp_favorite = {"path": path, "node_path": node_path}
	return find_favorite_index(temp_favorite)

# Find favorite index by favorite object
func find_favorite_index(favorite: Dictionary) -> int:
	for i in range(favorites.size()):
		if _favorites_match(favorites[i], favorite):
			return i
	return -1

# Calculate path relative to scene root node
func get_node_path(node: Node) -> String:
	var scene_root = EditorInterface.get_edited_scene_root()
	var node_path = str(scene_root.get_path_to(node))
	return node_path

# Create a favorite dictionary from a node (unified node processing logic)
func create_favorite_from_node(node: Node) -> Dictionary:
	var scene_root = EditorInterface.get_edited_scene_root()
	var scene_path = scene_root.scene_file_path if scene_root else ""
	
	# If node has its own scene file path, use it; otherwise use current edited scene path
	# if node.scene_file_path != "":
	# 	scene_path = node.scene_file_path
	
	return {
		"name": node.name + " (" + scene_path.get_file() + ")",
		"type": "node",
		"path": scene_path,
		"node_path": get_node_path(node)
	}

# Create a favorite dictionary from a file path (unified file processing logic)
func create_favorite_from_file(file_path: String) -> Dictionary:
	# Check if it's a folder
	var is_directory = DirAccess.dir_exists_absolute(file_path)
	debug_print("Creating favorite from file: " + file_path)
	
	var entry_name: String
	if is_directory:
		var slice_count = file_path.get_slice_count("/")
		debug_print("Directory slice count: " + str(slice_count))
		var splits = file_path.rsplit("/", false, 1)
		entry_name = splits[1]
	else:
		entry_name = file_path.get_file()
	
	return {
		"name": entry_name,
		"type": "folder" if is_directory else "file", 
		"path": file_path
	}

# Move favorite item up in the list
func move_favorite_up(favorite: Dictionary) -> bool:
	var index = favorites.find(favorite)
	if index > 0:
		# Swap with previous item
		var temp = favorites[index - 1]
		favorites[index - 1] = favorites[index]
		favorites[index] = temp
		save_favorites()
		debug_print("Moved favorite up: " + favorite.name)
		return true
	return false

# Move favorite item down in the list
func move_favorite_down(favorite: Dictionary) -> bool:
	var index = favorites.find(favorite)
	if index >= 0 and index < favorites.size() - 1:
		# Swap with next item
		var temp = favorites[index + 1]
		favorites[index + 1] = favorites[index]
		favorites[index] = temp
		save_favorites()
		debug_print("Moved favorite down: " + favorite.name)
		return true
	return false

# Settings management
func get_setting(key: String, default_value = null):
	return settings.get(key, default_value)

func set_setting(key: String, value):
	settings[key] = value
	# Update debug_enabled if it's changed
	if key == "debug_enabled":
		debug_enabled = value
	save_favorites()

func save_favorites():
	var data = {
		"favorites": favorites,
		"settings": settings
	}
	var file = FileAccess.open(FAVORITES_FILE, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(data)
		file.store_string(json_string)
		file.close()
		debug_print("Favorites data saved")
	else:
		debug_print("Failed to save favorites data")

func load_favorites():
	if not FileAccess.file_exists(FAVORITES_FILE):
		debug_print("Favorites file does not exist, creating new favorites")
		return
	
	var file = FileAccess.open(FAVORITES_FILE, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		
		if parse_result == OK:
			var data = json.data
			# Handle both old format (array) and new format (dictionary)
			if data is Array:
				# Old format - just favorites array
				favorites = data
				debug_print("Loaded old format favorites data, " + str(favorites.size()) + " items")
			elif data is Dictionary:
				# New format - favorites and settings
				favorites = data.get("favorites", [])
				var loaded_settings = data.get("settings", {})
				# Merge loaded settings with defaults
				for key in settings.keys():
					if loaded_settings.has(key):
						settings[key] = loaded_settings[key]
				# Update debug_enabled from settings
				debug_enabled = settings.get("debug_enabled", true)
				debug_print("Loaded favorites data, " + str(favorites.size()) + " items and settings")
			else:
				debug_print("Invalid data format")
				favorites = []
		else:
			debug_print("Failed to parse favorites data")
			favorites = []
	else:
		debug_print("Failed to read favorites data")
		favorites = []
