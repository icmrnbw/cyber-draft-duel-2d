extends Node
## Autoload. Player-facing options, persisted separately from PlayerProfile
## so wiping progress (settings_screen.gd's reset) doesn't also flip the
## player's sound preference back on.

const SAVE_PATH := "user://settings.json"

var sfx_enabled: bool = true


func _ready() -> void:
	_load()


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY:
		return
	sfx_enabled = bool(data.get("sfx_enabled", true))


func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"sfx_enabled": sfx_enabled}))
	f.close()
