extends RefCounted
## Shared dev-tool output guard. Only PNGs below project builds/ are allowed.
## No delete, move or user:// operations exist in this helper.
static func checked_png_path(requested: String) -> String:
	var normalized := requested.replace("\\", "/")
	if normalized.is_empty() or normalized.begins_with("user://") or ".." in normalized.split("/"):
		return ""
	var project := ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/")
	var output := ProjectSettings.globalize_path(normalized).replace("\\", "/")
	if not output.is_absolute_path():
		return ""
	output = output.simplify_path()
	if not output.begins_with(project + "/builds/") or output.get_extension().to_lower() != "png":
		return ""
	# Check every existing ancestor from the drive/root, including the output.
	# DirAccess.is_link also detects Windows reparse-point directories/junctions.
	var parts := output.split("/", false)
	var cursor := "/" if output.begins_with("/") else parts[0] + "/"
	var start := 0 if output.begins_with("/") else 1
	for i in range(start, parts.size()):
		if ":" in parts[i]:
			return ""
		var directory := DirAccess.open(cursor)
		if directory != null and directory.is_link(parts[i]):
			return ""
		cursor = cursor.path_join(parts[i])
	return output
