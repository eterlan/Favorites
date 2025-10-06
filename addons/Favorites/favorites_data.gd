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

func add_favorite(favorite: Dictionary):
	# Check if the same favorite item already exists
	for existing in favorites:
		if existing.path == favorite.path and existing.get("node_path", "") == favorite.get("node_path", ""):
			debug_print("Item already exists: " + favorite.name)
			return
	
	favorites.append(favorite)
	save_favorites()
	debug_print("Added favorite: " + favorite.name)

func remove_favorite(favorite: Dictionary):
	for i in range(favorites.size()):
		var existing = favorites[i]
		if existing.path == favorite.path and existing.get("node_path", "") == favorite.get("node_path", ""):
			favorites.remove_at(i)
			save_favorites()
			debug_print("Removed favorite: " + favorite.name)
			return

func get_favorites() -> Array:
	return favorites

# Check if already favorited
func is_favorited(path: String, node_path: String = "") -> bool:
	for existing in favorites:
		if existing.path == path and existing.get("node_path", "") == node_path:
			return true
	return false

# Find favorite item by path
func find_favorite(path: String, node_path: String = "") -> Dictionary:
	for existing in favorites:
		if existing.path == path and existing.get("node_path", "") == node_path:
			return existing
	return {}

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