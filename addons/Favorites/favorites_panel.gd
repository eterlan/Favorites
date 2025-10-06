@tool
class_name FavoritesPanel
extends Control

const FavoritesData = preload("res://addons/favorites/favorites_data.gd")

const FILE_SYSTEM: StringName = "FileSystem"
const SCENE: StringName = "Scene"
const SCRIPT_EDITOR: StringName = "ScriptEditor"

var favorites_data: FavoritesData
var tree: Tree
var add_button: Button
var remove_button: Button
var settings_button: Button
var settings_popup: PopupMenu
var search_line_edit: LineEdit
var all_favorites: Array = []

var is_focused_file_system: bool = false
var is_focused_scene_tree_editor: bool = false
var is_focused_script_editor: bool = false
var last_focused_editor: String = ""

var file_system_dock: FileSystemDock
var file_system_tree: Tree
var main_window: Window

func _init() -> void:
	name = "Favorites"
	set_custom_minimum_size(Vector2(200, 300))
	
	# Initialize data manager
	favorites_data = FavoritesData.new()

func _enter_tree() -> void:
	# Create UI
	_create_ui()

	# Load favorites data and settings
	favorites_data.load_favorites()
	file_system_dock = EditorInterface.get_file_system_dock()
	main_window = file_system_dock.get_window()
	main_window.gui_focus_changed.connect(_on_main_window_gui_focus_changed)
	_refresh_tree()

func _exit_tree() -> void:
	main_window.gui_focus_changed.disconnect(_on_main_window_gui_focus_changed)

# SceneTreeDock
func _on_main_window_gui_focus_changed(_control: Control):
	is_focused_file_system = _control.get_node("../..").name == FILE_SYSTEM
	if is_focused_file_system:
		last_focused_editor = FILE_SYSTEM
		return
	is_focused_scene_tree_editor = _control.get_node("../..").name == SCENE
	if is_focused_scene_tree_editor:
		last_focused_editor = SCENE
		return
	is_focused_script_editor = is_instance_of(_control, CodeEdit)
	if is_focused_script_editor:
		last_focused_editor = SCRIPT_EDITOR
		return

func _create_ui():
	# Create vertical layout
	var vbox = VBoxContainer.new()
	add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Search container with settings button
	var search_hbox = HBoxContainer.new()
	vbox.add_child(search_hbox)
	
	# Search box
	search_line_edit = LineEdit.new()
	search_line_edit.placeholder_text = "Search Favorites"
	search_line_edit.text_changed.connect(_on_search_text_changed)
	search_line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_hbox.add_child(search_line_edit)
	
	# Settings button
	settings_button = Button.new()
	settings_button.icon = EditorInterface.get_editor_theme().get_icon("Tools", "EditorIcons")
	settings_button.tooltip_text = "Settings"
	settings_button.flat = true
	settings_button.pressed.connect(_on_settings_pressed)
	search_hbox.add_child(settings_button)
	
	# Button container
	var button_hbox = HBoxContainer.new()
	vbox.add_child(button_hbox)
	
	# Add button
	add_button = Button.new()
	add_button.text = "Add selected"
	add_button.tooltip_text = "Add the selected node or file to favorites"
	add_button.pressed.connect(_on_add_current_pressed)
	button_hbox.add_child(add_button)
	
	# Remove button
	remove_button = Button.new()
	remove_button.text = "Remove selected"
	remove_button.tooltip_text = "Remove the selected favorite item"
	remove_button.pressed.connect(_on_remove_pressed)
	remove_button.disabled = true
	button_hbox.add_child(remove_button)
	
	# Create tree control
	tree = Tree.new()
	tree.allow_rmb_select = true
	tree.set_hide_root(true)
	# Enable drag and drop
	tree.set_drag_forwarding(_get_drag_data, _can_drop_data, _drop_data)
	tree.item_selected.connect(_on_item_selected)
	tree.item_activated.connect(_on_item_activated)
	tree.item_mouse_selected.connect(_on_item_mouse_selected)
	vbox.add_child(tree)
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Set focus mode to receive keyboard input
	set_focus_mode(Control.FOCUS_ALL)
	tree.set_focus_mode(Control.FOCUS_ALL)
	shortcut_context = tree

func _input(event: InputEvent):
	# Handle keyboard shortcuts
	if event as InputEventKey and event.is_pressed():
		var input_event_key = event as InputEventKey
		var is_cmd_or_ctrl = input_event_key.is_command_or_control_pressed()
		
		# Check if favorites panel has focus
		if tree.get_selected() and (has_focus() or tree.has_focus()):
			if is_cmd_or_ctrl and input_event_key.keycode == KEY_BACKSPACE:
				# Cmd+Delete (macOS) or Ctrl+Delete (Windows/Linux) - Remove
				_on_remove_pressed()
				get_viewport().set_input_as_handled()
			elif is_cmd_or_ctrl and input_event_key.keycode == KEY_UP:
				# Ctrl+Up Arrow - Move up
				_move_favorite_up()
				get_viewport().set_input_as_handled()
			elif is_cmd_or_ctrl and input_event_key.keycode == KEY_DOWN:
				# Ctrl+Down Arrow - Move down
				_move_favorite_down()
				get_viewport().set_input_as_handled()

func _refresh_tree():
	tree.clear()
	var root = tree.create_item()
	
	all_favorites = favorites_data.get_favorites()
	var search_text = search_line_edit.text.to_lower() if search_line_edit else ""
	
	for favorite in all_favorites:
		# If there's search text, filter non-matching items
		if search_text != "" and not favorite.name.to_lower().contains(search_text):
			continue
			
		var item = tree.create_item(root)
		item.set_text(0, favorite.name)
		item.set_tooltip_text(0, favorite.path)
		item.set_metadata(0, favorite)
		
		# Set icon based on type
		if favorite.type == "node":
			item.set_icon(0, get_theme_icon("Node", "EditorIcons"))
		elif favorite.type == "file":
			_set_file_icon(item, favorite.path)
		elif favorite.type == "folder":
			item.set_icon(0, get_theme_icon("Folder", "EditorIcons"))
		
		# Set custom color (if any)
		if favorite.has("color"):
			var color = Color(favorite.color)
			item.set_custom_bg_color(0, color)

func _set_file_icon(item: TreeItem, file_path: String):
	var file_extension = file_path.get_extension().to_lower()
	var icon_name = "File"  # Default icon
	
	match file_extension:
		"gd":
			icon_name = "GDScript"
		"cs":
			icon_name = "CSharpScript"
		"tscn":
			icon_name = "PackedScene"
		"scn":
			icon_name = "PackedScene"
		"tres":
			icon_name = "Resource"
		"res":
			icon_name = "Resource"
		"png", "jpg", "jpeg", "svg", "webp":
			icon_name = "ImageTexture"
		"wav", "ogg", "mp3":
			icon_name = "AudioStreamPlayer"
		"txt", "md", "json":
			icon_name = "TextFile"
		_:
			icon_name = "File"
	
	item.set_icon(0, get_theme_icon(icon_name, "EditorIcons"))

func _on_add_current_pressed():
	# First check if file system window has selected files

	match last_focused_editor:
		FILE_SYSTEM:
			var selected_paths = EditorInterface.get_selected_paths()
			favorites_data.debug_print("Selected paths: " + str(selected_paths))
			if selected_paths.size() > 0:
				# File system has selected files, prioritize adding these files
				for path in selected_paths:
					favorites_data.debug_print("Processing path: " + path)
					if FileAccess.file_exists(path):  # Ensure it's a file, not a directory
						add_file_to_favorites(path)

		SCENE:
			var selection = EditorInterface.get_selection()
			var selected_nodes = selection.get_selected_nodes()
			
			if selected_nodes.size() > 0:
				# Add selected nodes
				for node in selected_nodes:
					add_node_to_favorites(node)

		SCRIPT_EDITOR:
			var current_script = EditorInterface.get_script_editor().get_current_script()
			if current_script:
				add_file_to_favorites(current_script.resource_path)


func add_node_to_favorites(node: Node):
	var favorite = favorites_data.create_favorite_from_node(node)
	var index = favorites_data.find_favorite_index(favorite)
	if index == -1:
		favorites_data.add_favorite(favorite)
		index = favorites_data.favorites.size() - 1
	
	# Auto select new_item if added successfully
	_refresh_tree()
	_select_item(index)

func add_file_to_favorites(file_path: String):
	var favorite = favorites_data.create_favorite_from_file(file_path)
	var index = favorites_data.find_favorite_index(favorite)
	if index == -1:
		favorites_data.add_favorite(favorite)
		index = favorites_data.favorites.size() - 1
	
	# Auto select new_item if added successfully
	_refresh_tree()
	_select_item(index)
	

func _on_item_selected():
	remove_button.disabled = false

func _on_item_activated():
	var selected_item = tree.get_selected()
	if not selected_item:
		return
	
	var favorite = selected_item.get_metadata(0)
	_navigate_to_favorite(favorite)

func _on_item_mouse_selected(mouse_pos: Vector2, mouse_button_index: int):
	var selected_item = tree.get_selected()
	if selected_item and mouse_button_index == MOUSE_BUTTON_RIGHT:
		_show_context_menu(mouse_pos)

func _show_context_menu(mouse_pos: Vector2):
	favorites_data.debug_print("Show context menu at mouse_pos: " + str(mouse_pos))
	var popup_menu: PopupMenu = PopupMenu.new()
	add_child(popup_menu)
	# Add menu items
	popup_menu.add_item("Move Up", 0)
	popup_menu.add_item("Move Down", 1)
	popup_menu.add_separator()
	popup_menu.add_item("Remove", 2)
	popup_menu.add_separator()
	popup_menu.add_item("Change Color", 3)
	popup_menu.add_item("Reset Color", 4)
	
	# Connect menu item selection signal
	popup_menu.id_pressed.connect(_on_context_menu_selected)
	
	# Show menu
	favorites_data.debug_print("Menu position: " + str(mouse_pos))
	popup_menu.position =  mouse_pos + global_position + Vector2(popup_menu.size.x/2, popup_menu.size.y)
	popup_menu.popup()
	
	# Auto-delete menu after closing
	popup_menu.popup_hide.connect(func(): popup_menu.queue_free())

func _on_context_menu_selected(id: int):
	var selected_item = tree.get_selected()
	if not selected_item:
		return
	
	match id:
		0: # Move Up
			_move_favorite_up()
		1: # Move Down
			_move_favorite_down()
		2: # Remove favorite
			_on_remove_pressed()
		3: # Change color
			_show_color_picker()
		4: # Reset color
			_reset_item_color()

func _navigate_to_favorite(favorite: Dictionary):
	if favorite.type == "node":
		_navigate_to_node(favorite)
	elif favorite.type == "file":
		_navigate_to_file(favorite)
	elif favorite.type == "folder":
		_navigate_to_folder(favorite)

func _navigate_to_node(favorite: Dictionary):
	var scene_root = EditorInterface.get_edited_scene_root()
	var target_node = null
	
	# First try to find node in current scene
	if scene_root:
		if favorite.node_path == ".":
			# If path is ".", it represents the scene root node
			target_node = scene_root
		else:
			# Use relative path to find node
			target_node = scene_root.get_node_or_null(favorite.node_path)
		
		# If node is found in current scene, navigate directly
		if target_node:
			EditorInterface.get_selection().clear()
			EditorInterface.get_selection().add_node(target_node)
			favorites_data.debug_print("Navigated to node in current scene: " + favorite.node_path)
			
			# Auto-switch to appropriate scene editor if setting is enabled
			if favorites_data.get_setting("auto_switch_to_scene", false):
				_switch_to_scene_editor(scene_root)
			return
	
	# Get current scene path
	var current_scene_path = ""
	if scene_root:
		current_scene_path = scene_root.scene_file_path
	
	# If current scene is not the target scene, open target scene
	if current_scene_path != favorite.path:
		favorites_data.debug_print("Opening scene file: " + favorite.path)
		EditorInterface.open_scene_from_path(favorite.path)
		
		# Wait for scene to load then select node
		await get_tree().process_frame
		
		scene_root = EditorInterface.get_edited_scene_root()
		if scene_root:
			if favorite.node_path == ".":
				target_node = scene_root
			else:
				target_node = scene_root.get_node_or_null(favorite.node_path)
				
			if target_node:
				EditorInterface.get_selection().clear()
				EditorInterface.get_selection().add_node(target_node)
				favorites_data.debug_print("Navigated to node in newly opened scene: " + favorite.node_path)
				
				# Auto-switch to appropriate scene editor if setting is enabled
				if favorites_data.get_setting("auto_switch_to_scene", false):
					_switch_to_scene_editor(scene_root)
			else:
				favorites_data.debug_print("Node not found in newly opened scene: " + favorite.node_path)
		else:
			favorites_data.debug_print("No scene root found after opening scene")
	else:
		favorites_data.debug_print("Node not found: " + favorite.node_path + " (in current scene " + current_scene_path + ")")

func _navigate_to_file(favorite: Dictionary):
	# Select file in file system
	file_system_dock.navigate_to_path(favorite.path)
	
	# Handle different file types
	var file_extension = favorite.path.get_extension().to_lower()
	
	match file_extension:
		"gd", "cs":
			# Script files: open in script editor
			var script = load(favorite.path)
			if script:
				EditorInterface.edit_script(script)
				favorites_data.debug_print("Opened in script editor: " + favorite.name)
				
				# Auto-switch to script editor if setting is enabled
				if favorites_data.get_setting("auto_switch_to_script", false):
					EditorInterface.set_main_screen_editor("Script")
			else:
				favorites_data.debug_print("Failed to load script: " + favorite.path)
		
		"tscn", "scn":
			# Scene files: open in scene editor
			EditorInterface.open_scene_from_path(favorite.path)
			favorites_data.debug_print("Opened in scene editor: " + favorite.name)
		
		"tres", "res":
			# Resource files: open in inspector
			var resource = load(favorite.path)
			if resource:
				EditorInterface.edit_resource(resource)
				favorites_data.debug_print("Opened resource in inspector: " + favorite.name)
			else:
				favorites_data.debug_print("Failed to load resource: " + favorite.path)
		
		_:
			# Other file types: only locate in file system
			favorites_data.debug_print("Located file in file system: " + favorite.name)

func _navigate_to_folder(favorite: Dictionary):
	# Navigate to folder in file system
	file_system_dock.navigate_to_path(favorite.path)
	favorites_data.debug_print("Navigate to folder in file system: " + favorite.name)

func _on_remove_pressed():
	var selected_item = tree.get_selected()
	if not selected_item:
		return
	
	# Get the index of the item being removed
	var removed_index = _get_item_index(selected_item)
	remove_favorite(removed_index)	

func remove_favorite(index: int):
	favorites_data.remove_favorite(index)
	_refresh_tree()
	
	# Select item at original position, or previous one if not available
	_select_item(index - 1)
	
	# Update remove button state
	remove_button.disabled = not tree.get_selected() 

func _on_search_text_changed(new_text: String):
	_refresh_tree()

func _show_color_picker():
	var selected_item = tree.get_selected()
	if not selected_item:
		return
	
	var color_picker_dialog = AcceptDialog.new()
	color_picker_dialog.title = "Choose Color"
	color_picker_dialog.size = Vector2i(300, 400)
	add_child(color_picker_dialog)
	
	var color_picker = ColorPicker.new()
	color_picker.color = Color.WHITE  # Default color
	
	# If color already exists, use existing color
	var favorite = selected_item.get_metadata(0)
	if favorite.has("color"):
		color_picker.color = Color(favorite.color)
	
	color_picker_dialog.add_child(color_picker)
	
	# Connect confirmation signal
	color_picker_dialog.confirmed.connect(func(): _apply_color(color_picker.color))
	color_picker_dialog.canceled.connect(func(): color_picker_dialog.queue_free())
	
	color_picker_dialog.popup_centered()

func _apply_color(color: Color):
	var selected_item = tree.get_selected()
	if not selected_item:
		return
	
	var favorite = selected_item.get_metadata(0)
	favorite["color"] = color.to_html()
	
	# Update data and refresh display
	favorites_data.save_favorites()
	_refresh_tree()

func _reset_item_color():
	var selected_item = tree.get_selected()
	if not selected_item:
		return
	
	var favorite = selected_item.get_metadata(0)
	if favorite.has("color"):
		favorite.erase("color")
		
		# Update data and refresh display
		favorites_data.save_favorites()
		_refresh_tree()

# Settings functions
func _on_settings_pressed():
	if not settings_popup:
		_create_settings_popup()
	
	# Position popup below the settings button
	var button_global_pos = settings_button.global_position
	var button_size = settings_button.size
	settings_popup.position = Vector2i(button_global_pos.x, button_global_pos.y + button_size.y)
	settings_popup.popup()

func _create_settings_popup():
	settings_popup = PopupMenu.new()
	add_child(settings_popup)
	
	# Add toggle option for auto-switching to script editor
	settings_popup.add_check_item("Auto-switch to Script Editor")
	settings_popup.set_item_checked(0, favorites_data.get_setting("auto_switch_to_script", false))
	settings_popup.set_item_tooltip(0, "Automatically switch to Script Editor when opening script files")
	
	# Add toggle option for auto-switching to scene editor
	settings_popup.add_check_item("Auto-switch to Scene Editor")
	settings_popup.set_item_checked(1, favorites_data.get_setting("auto_switch_to_scene", false))
	settings_popup.set_item_tooltip(1, "Automatically switch to Scene Editor when selecting scene nodes")
	
	# Add debug toggle
	settings_popup.add_check_item("Enable Debug Output")
	settings_popup.set_item_checked(2, favorites_data.get_setting("debug_enabled", true))
	settings_popup.set_item_tooltip(2, "Enable debug output in console")
	
	# Connect signal
	settings_popup.id_pressed.connect(_on_settings_item_selected)

func _on_settings_item_selected(id: int):
	match id:
		0: # Auto-switch to Script Editor
			var new_value = !favorites_data.get_setting("auto_switch_to_script", false)
			favorites_data.set_setting("auto_switch_to_script", new_value)
			settings_popup.set_item_checked(0, new_value)
		1: # Auto-switch to Scene Editor
			var new_value = !favorites_data.get_setting("auto_switch_to_scene", false)
			favorites_data.set_setting("auto_switch_to_scene", new_value)
			settings_popup.set_item_checked(1, new_value)
		2: # Enable Debug Output
			var new_value = !favorites_data.get_setting("debug_enabled", true)
			favorites_data.set_setting("debug_enabled", new_value)
			settings_popup.set_item_checked(2, new_value)

func _switch_to_scene_editor(scene_root: Node):
	if not scene_root:
		return
	
	# Determine scene type based on root node
	var editor_name = ""
	if scene_root is Node2D or scene_root is Control:
		editor_name = "2D"
		favorites_data.debug_print("Switching to 2D Scene Editor")
	elif scene_root is Node3D:
		editor_name = "3D"
		favorites_data.debug_print("Switching to 3D Scene Editor")
	else:
		# Default to 2D for other node types
		editor_name = "2D"
		favorites_data.debug_print("Switching to 2D Scene Editor (default)")
	
	EditorInterface.set_main_screen_editor(editor_name)

func _move_favorite_up():
	var selected_item = tree.get_selected()
	if not selected_item:
		return
	
	var favorite = selected_item.get_metadata(0)
	if favorites_data.move_favorite_up(favorite):
		_refresh_tree()
		# Re-select the moved item
		_select_favorite_after_refresh(favorite)

func _move_favorite_down():
	var selected_item = tree.get_selected()
	if not selected_item:
		return
	
	var favorite = selected_item.get_metadata(0)
	if favorites_data.move_favorite_down(favorite):
		_refresh_tree()
		# Re-select the moved item
		_select_favorite_after_refresh(favorite)

func _select_favorite_after_refresh(target_favorite: Dictionary):
	# Find and select the item after refresh
	var root = tree.get_root()
	if not root:
		return
	
	var child_count = root.get_child_count()
	for i in range(child_count):
		var child = root.get_child(i)
		var favorite = child.get_metadata(0)
		if favorites_data._favorites_match(favorite, target_favorite):
			child.select(0)
			break

# Drag and drop functionality
func _get_drag_data(position: Vector2):
	var item = tree.get_item_at_position(position)
	if not item:
		return null
	
	var favorite = item.get_metadata(0)
	if not favorite:
		return null
	
	# Create drag preview
	var preview = Label.new()
	preview.text = favorite.name
	preview.add_theme_color_override("font_color", Color.WHITE)
	preview.add_theme_color_override("font_shadow_color", Color.BLACK)
	preview.add_theme_constant_override("shadow_offset_x", 1)
	preview.add_theme_constant_override("shadow_offset_y", 1)
	set_drag_preview(preview)
	
	# Return drag data
	return {
		"type": "favorite_item",
		"source_item": item,
		"favorite": favorite,
		"source_index": _get_item_index(item)
	}

func _can_drop_data(position: Vector2, data) -> bool:
	if not data is Dictionary:
		return false
	if data.get("type") != "favorite_item":
		return false
	
	var target_item = tree.get_item_at_position(position)
	if not target_item:
		return false
	
	# Don't allow dropping on the same item
	if target_item == data.get("source_item"):
		return false
	
	return true

func _drop_data(position: Vector2, data):
	if not _can_drop_data(position, data):
		return
	
	var target_item = tree.get_item_at_position(position)
	var source_favorite = data.get("favorite")
	var target_favorite = target_item.get_metadata(0)
	
	var source_index = data.get("source_index")
	var target_index = _get_item_index(target_item)
	
	# Reorder the favorites data
	_reorder_favorites(source_index, target_index)
	
	# Refresh the tree and select the moved item
	_refresh_tree()
	_select_favorite_after_refresh(source_favorite)

func _get_item_index(item: TreeItem) -> int:
	var root = tree.get_root()
	if not root:
		return -1
	
	var child_count = root.get_child_count()
	for i in range(child_count):
		if root.get_child(i) == item:
			return i
	return -1

func _reorder_favorites(from_index: int, to_index: int):
	var favorites = favorites_data.favorites
	if from_index < 0 or from_index >= favorites.size():
		return
	if to_index < 0 or to_index >= favorites.size():
		return
	if from_index == to_index:
		return
	
	# Remove the item from its original position
	var item = favorites[from_index]
	favorites.remove_at(from_index)
	
	# Adjust target index if necessary
	if from_index < to_index:
		to_index -= 1
	
	# Insert the item at the new position
	favorites.insert(to_index, item)
	
	# Save the reordered favorites
	favorites_data.save_favorites()

# Selection helper functions
func _select_item(index: int):
	var root = tree.get_root()
	if not root:
		return
	
	var child_count = root.get_child_count()
	if child_count == 0:
		return
	
	# Select the item at index
	var item = root.get_child(index)
	item.select(0)
	remove_button.disabled = false

