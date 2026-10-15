extends Node
## Holds the current profile and saves it (user:// maps to browser storage on the web build).

const SAVE_PATH := "user://save.json"

var profile: Dictionary = {}


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func new_game() -> void:
	profile = Profile.create()
	save_game()


func load_game() -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	if not data is Dictionary or not data.has("version"):
		return false
	profile = Profile.create()
	profile.merge(data, true)
	return true


func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(profile, "\t"))


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
