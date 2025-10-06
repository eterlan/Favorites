@tool
extends EditorContextMenuPlugin

var favorites_data: FavoritesData
var favorites_panel

func _init(favorites_data_instance: FavoritesData, favorites_panel_instance):
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
		
		# Calculate node path
		var node_path: String
		if node == scene_root:
			node_path = "."
		else:
			node_path = str(scene_root.get_path_to(node))
		
		# Check if already favorited
		var is_favorited = false
		for favorite in favorites_data.get_favorites():
			if favorite.type == "node" and favorite.path == scene_root.scene_file_path and favorite.node_path == node_path:
				is_favorited = true
				break
		
		var menu_text = "Remove from Favorites" if is_favorited else "Add to Favorites"
		add_context_menu_item(menu_text, _on_node_menu_selected)

func _on_node_menu_selected(selected_nodes: Array):
	# Get the first selected node
	if selected_nodes.size() > 0:
		var node = selected_nodes[0]
		var scene_root = EditorInterface.get_edited_scene_root()
		
		if not scene_root or not scene_root.scene_file_path:
			return
		
		# Calculate node path
		var node_path: String
		if node == scene_root:
			node_path = "."
		else:
			node_path = str(scene_root.get_path_to(node))
		
		# Check if already favorited
		var is_favorited = false
		var favorite_to_remove = null
		for favorite in favorites_data.get_favorites():
			if favorite.type == "node" and favorite.path == scene_root.scene_file_path and favorite.node_path == node_path:
				is_favorited = true
				favorite_to_remove = favorite
				break
		
		if is_favorited:
			# Remove from favorites
			if favorite_to_remove:
				favorites_data.remove_favorite(favorite_to_remove)
				favorites_data.debug_print("Removed node from favorites: " + node.name)
		else:
			# Add to favorites
			favorites_panel._add_node_to_favorites(node)
			favorites_data.debug_print("Added node to favorites: " + node.name)
		
		# Refresh favorites panel
		if favorites_panel:
			favorites_panel._refresh_tree()