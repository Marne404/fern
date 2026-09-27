extends SceneTree
## Exports the scout as a glTF binary for the website (all hats and face parts visible;
## the page picks what to show by node name, colors by material name).
## godot --headless --path . -s res://scripts/tests/scout_export.gd -- --out=docs/models/scout.glb

func _initialize() -> void:
	var out := "docs/models/scout.glb"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	var scout := Scout.new({}, true)
	root.add_child(scout)
	for n in scout.find_children("*", "Node3D", true, false):
		(n as Node3D).visible = true
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(scout, state)
	if err == OK:
		err = doc.write_to_filesystem(state, ProjectSettings.globalize_path("res://" + out) if not out.begins_with("/") else out)
	print("export %s: %s" % [out, error_string(err)])
	quit()
