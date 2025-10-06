@tool
extends EditorContextMenuPlugin

var favorites_data: FavoritesData
var favorites_panel: FavoritesPanel

func _init(favorites_data_instance: FavoritesData, favorites_panel_instance: FavoritesPanel):
	favorites_data = favorites_data_instance
	favorites_panel = favorites_panel_instance

func _popup_menu(paths: PackedStringArray):
	# Get currently selected nodes
	var selected_nodes = EditorInterface.get_selection().get_selected_nodes()
	if selected_nodes.size() > 0:
		var node = selected_nodes[0]
		var scene_root = EditorInterface.get_edited_scene_root()
		if not scene_root or not scene_root.scene_file_path:
			return

		# Create favorite from node using unified logic
		var favorite = favorites_data.create_favorite_from_node(node)
		
		# Check if already favorited
		var index = favorites_data.find_favorite_index(favorite)
		
		var menu_text = "Remove from Favorites" if index != -1 else "Add to Favorites"
		add_context_menu_item(menu_text, _on_node_menu_selected.bind(index))

func _on_node_menu_selected(nodes: Array, index: int):
		if index != -1:
			# Remove from favorites
			favorites_panel.remove_favorite(index)
			favorites_data.debug_print("Removed node from favorites: " + nodes[0].name)
		else:
			# Add to favorites
			favorites_panel.add_node_to_favorites(nodes[0])
			favorites_data.debug_print("Added node to favorites: " + nodes[0].name)
