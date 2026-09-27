extends Node
## Real-signal test of the voice gate: record from an output monitor (or the chosen device) while the
## harmonica plays, then report the measured levels. Start: godot --path . -- --voicetest[=device]

var main: Node


func run(device: String) -> void:
	Settings.persist = false
	print("== Voice test ==")
	print("  devices: %s" % ", ".join(Voice.devices()))
	var dev := device
	if dev == "1" or dev == "":
		dev = "Default"
		for d in Voice.devices():
			if "monitor" in d.to_lower() and "analog" in d.to_lower():
				dev = d
	Settings.set_value("voice_device", dev, false)
	Settings.set_value("voice_mode", 2, false)
	Settings.set_value("voice_threshold", -45.0, false)
	Settings.set_value("voice_enabled", true, false)
	await get_tree().create_timer(0.8).timeout
	var quiet_max := -80.0
	for i in 60:
		await get_tree().process_frame
		quiet_max = maxf(quiet_max, Voice.level_db)
	var opened := false
	var loud_max := -80.0
	for rep in 2:
		Sfx.play(self, "harmonica", 0.0)
		var t := 0.0
		while t < 3.2:
			await get_tree().process_frame
			t += get_process_delta_time()
			loud_max = maxf(loud_max, Voice.level_db)
			opened = opened or Voice.transmitting
	print("  device: %s  active: %s" % [dev, Voice.active])
	print("  quiet max %.1f dB, while playing max %.1f dB, voice share %.2f, voice activation opened: %s" % [quiet_max, loud_max, Voice.voice_share, opened])
	print("== %s ==" % ("PASSED" if Voice.active and opened and loud_max > quiet_max + 10.0 else "FAILED"))
	get_tree().quit()
