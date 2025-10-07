@tool
extends EditorPlugin

const FavoritesPanel = preload("res://addons/Favorites/favorites_panel.gd")
const FileSystemContextMenuPlugin = preload("res://addons/Favorites/file_system_context_menu_plugin.gd")
const SceneTreeContextMenuPlugin = preload("res://addons/Favorites/scene_tree_context_menu_plugin.gd")
const icon = preload("res://addons/Favorites/icon.png")

var favorites_panel_instance
var filesystem_context_menu_plugin
var scene_tree_context_menu_plugin

func _get_plugin_name() -> String:
	return "Favorites"

func _enter_tree():
	# Create favorites panel
	favorites_panel_instance = FavoritesPanel.new()
	
	# Add to editor dock panel
	add_control_to_dock(DOCK_SLOT_LEFT_UL, favorites_panel_instance)
	set_dock_tab_icon(favorites_panel_instance, icon)
	
	# Create and register context menu plugins
	var favorites_data = favorites_panel_instance.favorites_data
	
	# File system context menu
	filesystem_context_menu_plugin = FileSystemContextMenuPlugin.new(favorites_data, favorites_panel_instance)
	add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM, filesystem_context_menu_plugin)
	
	# Scene tree context menu
	scene_tree_context_menu_plugin = SceneTreeContextMenuPlugin.new(favorites_data, favorites_panel_instance)
	add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_SCENE_TREE, scene_tree_context_menu_plugin)
	
	print("Favorites plugin enabled")

func _exit_tree():
	# Remove context menu plugins
	if filesystem_context_menu_plugin:
		remove_context_menu_plugin(filesystem_context_menu_plugin)
		filesystem_context_menu_plugin = null
	
	if scene_tree_context_menu_plugin:
		remove_context_menu_plugin(scene_tree_context_menu_plugin)
		scene_tree_context_menu_plugin = null
	
	# Remove favorites panel
	if favorites_panel_instance:
		remove_control_from_docks(favorites_panel_instance)
		favorites_panel_instance.queue_free()
		favorites_panel_instance = null
	
	# Remove context menu items
	remove_tool_menu_item("Add to Favorites")
	
	print("Favorites plugin disabled")

func _add_to_favorites():
	if favorites_panel_instance:
		favorites_panel_instance._on_add_current_pressed()