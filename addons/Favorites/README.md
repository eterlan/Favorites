# Favorites Plugin for Godot

A simple and efficient favorites plugin for Godot Editor that allows you to bookmark scene nodes and files for quick navigation.

## Features

- **Bookmark Nodes & Files**: Add scene nodes and project files to your favorites
- **Smart Detection**: Automatically detects current focus (scene tree or file system)
- **Quick Navigation**: Double-click to instantly jump to bookmarked items
- **File Type Icons**: Different icons for scripts, scenes, resources, and other file types
- **Search**: Filter favorites with built-in search functionality
- **Persistent Storage**: Favorites are saved and restored between editor sessions

## Installation

1. Copy the `favorites` folder to your project's `addons` directory
2. Enable the "Favorites" plugin in Project Settings
3. The Favorites panel will appear in the editor's left dock area

## Usage

### Adding Favorites

- **Nodes**: Select a node in the scene tree → click "Add Current"
- **Files**: Select files in the file system dock → click "Add Current"
- **Scripts**: While editing a script → click "Add Current"

### Navigation

Double-click any favorite item:
- **Nodes**: Selects the node in scene tree (opens scene if needed)
- **Scripts**: Opens in script editor
- **Scenes**: Opens in scene editor
- **Other files**: Locates in file system

### Management

- **Search**: Use the search box to filter favorites
- **Remove**: Select item → click "Remove" button
- **Colors**: Right-click items to set custom colors

## File Types Supported

- Scene files (`.tscn`)
- Script files (`.gd`, `.cs`)
- Resource files (`.tres`, `.res`)
- Image files (`.png`, `.jpg`, `.svg`)
- Audio files (`.wav`, `.ogg`, `.mp3`)
- Text files (`.txt`, `.md`, `.json`)
- All other project files

## Data Storage

Favorites are stored in `user://favorites.json` and remain separate between projects.

## License

This plugin is released under the MIT License.