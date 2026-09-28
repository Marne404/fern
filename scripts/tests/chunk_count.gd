extends SceneTree
## Counts the instances per model in one near chunk: godot --headless -s res://scripts/tests/chunk_count.gd -- --z=-11330 --x=10


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var gen := WorldGen.new(int(args.get("seed", "1")))
	var z := float(args.get("z", "-1000"))
	var x := gen.path_x(z) + float(args.get("x", "0"))
	var c := Vector2i(floori(x / 64.0), floori(z / 64.0))
	var b := ChunkBuilder.new(gen, c, 0, 1.0)
	var res := b.build()
	var per := {}
	for k in res["counts"]:
		var key: String = k.get_slice("#", 0)
		per[key] = int(per.get(key, 0)) + int(res["counts"][k])
	var keys := per.keys()
	keys.sort()
	for k in keys:
		print("%6d  %s" % [per[k], k])
	quit()
