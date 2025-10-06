@tool
extends Control

const FavoritesData = preload("res://addons/favorites/favorites_data.gd")

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
var last_focused_file_system: bool = false
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
	is_focused_file_system = _control.get_node("../..").name == &"FileSystem"
	is_focused_scene_tree_editor = _control.get_node("../..").name == &"Scene"
	if is_focused_file_system:
		last_focused_file_system = true
	elif is_focused_scene_tree_editor:
		last_focused_file_system = false

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
	# Handle Cmd+Delete (macOS) or Ctrl+Delete (Windows/Linux) shortcut
	if event as InputEventKey and event.is_pressed():
		var input_event_key = event as InputEventKey
		var is_cmd_or_ctrl = input_event_key.is_command_or_control_pressed()
		if is_cmd_or_ctrl and input_event_key.keycode == KEY_BACKSPACE:
			# Check if there's a selected item and favorites panel has focus
			if tree.get_selected() and (has_focus() or tree.has_focus()):
				_on_remove_pressed()
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
	if last_focused_file_system:
		var selected_paths = EditorInterface.get_selected_paths()
		favorites_data.debug_print("Selected paths: " + str(selected_paths))
		if selected_paths.size() > 0:
			# File system has selected files, prioritize adding these files
			for path in selected_paths:
				favorites_data.debug_print("Processing path: " + path)
				if FileAccess.file_exists(path):  # Ensure it's a file, not a directory
					_add_file_to_favorites(path)
			return
	
	# If file system has no selected files, check scene tree node selection
	var selection = EditorInterface.get_selection()
	var selected_nodes = selection.get_selected_nodes()
	
	if selected_nodes.size() > 0:
		# Add selected nodes
		for node in selected_nodes:
			_add_node_to_favorites(node)
		return
	
	# Finally try to add currently edited script
	var current_script = EditorInterface.get_script_editor().get_current_script()
	if current_script:
		_add_file_to_favorites(current_script.resource_path)

func _add_node_to_favorites(node: Node):
	var scene_root = EditorInterface.get_edited_scene_root()
	var scene_path = scene_root.scene_file_path if scene_root else ""
	
	# If node has its own scene file path, use it; otherwise use current edited scene path
	if node.scene_file_path != "":
		scene_path = node.scene_file_path
	
	# Calculate path relative to scene root node
	var node_path: String
	if scene_root and node != scene_root:
		node_path = str(scene_root.get_path_to(node))
	else:
		# If node is the scene root node
		node_path = "."
	
	var favorite = {
		"name": node.name + " (" + scene_path.get_file() + ")",
		"type": "node",
		"path": scene_path,
		"node_path": node_path
	}
	
	favorites_data.add_favorite(favorite)
	_refresh_tree()

func _add_file_to_favorites(file_path: String):
	# Check if it's a folder
	var is_directory = DirAccess.dir_exists_absolute(file_path)
	favorites_data.debug_print("Adding file to favorites: " + file_path)
	var entry_name: String
	if is_directory:
		var slice_count = file_path.get_slice_count("/")
		favorites_data.debug_print("Directory slice count: " + str(slice_count))
		var splits = file_path.rsplit("/", false, 1)
		entry_name = splits[1]
	else:
		entry_name = file_path.get_file()
	
	var favorite = {
		"name": entry_name,
		"type": "folder" if is_directory else "file", 
		"path": file_path
	}
	favorites_data.add_favorite(favorite)
	_refresh_tree()

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
	var popup_menu = PopupMenu.new()
	add_child(popup_menu)
	
	# Add menu items
	popup_menu.add_item("Remove", 0)
	popup_menu.add_separator()
	popup_menu.add_item("Change Color", 1)
	popup_menu.add_item("Reset Color", 2)
	
	# Connect menu item selection signal
	popup_menu.id_pressed.connect(_on_context_menu_selected)
	
	# Show menu
	favorites_data.debug_print("Menu position: " + str(mouse_pos))
	popup_menu.position =  mouse_pos + global_position + Vector2(popup_menu.size.x, 2 * popup_menu.size.y)
	popup_menu.popup()
	
	# Auto-delete menu after closing
	popup_menu.popup_hide.connect(func(): popup_menu.queue_free())

func _on_context_menu_selected(id: int):
	var selected_item = tree.get_selected()
	if not selected_item:
		return
	
	match id:
		0: # Remove favorite
			_on_remove_pressed()
		1: # Change color
			_show_color_picker()
		2: # Reset color
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
	
	var favorite = selected_item.get_metadata(0)
	favorites_data.remove_favorite(favorite)
	_refresh_tree()
	remove_button.disabled = true

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
	color_picker_dialog.popup_hide.connect(func(): color_picker_dialog.queue_free())
	
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
