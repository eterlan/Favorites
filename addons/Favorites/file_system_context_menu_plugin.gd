@tool
extends EditorContextMenuPlugin

var favorites_data: FavoritesData
var favorites_panel

func _init(favorites_data_instance: FavoritesData, favorites_panel_instance):
	favorites_data = favorites_data_instance
	favorites_panel = favorites_panel_instance

func _popup_menu(paths: PackedStringArray):
	if paths.size() > 0:
		var file_path = paths[0]
		var is_favorited = favorites_data.is_favorited(file_path)
		var menu_text = "Remove from Favorites" if is_favorited else "Add to Favorites"
		
		add_context_menu_item(menu_text, _on_file_menu_selected)

func _on_file_menu_selected(selected_paths: Array):
	if selected_paths.size() > 0:
		var file_path = selected_paths[0]
		var is_favorited = favorites_data.is_favorited(file_path)
		
		if is_favorited:
			# Remove from favorites
			var favorite_to_remove = null
			for favorite in favorites_data.get_favorites():
				if favorite.path == file_path:
					favorite_to_remove = favorite
					break
			
			if favorite_to_remove:
				favorites_data.remove_favorite(favorite_to_remove)
				favorites_data.debug_print("Removed from favorites: " + file_path)
		else:
			# Add to favorites
			favorites_panel._add_file_to_favorites(file_path)
			favorites_data.debug_print("Added to favorites: " + file_path)
		
		# Refresh favorites panel
		if favorites_panel:
			favorites_panel._refresh_tree()