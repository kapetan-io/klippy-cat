extends Node

# Headless smoke test for the WindowDetect Layer-3 module. Exercises the whole interface.
func _ready() -> void:
	var lines := PackedStringArray()
	if not ClassDB.class_exists("WindowDetect"):
		lines.append("FAIL: WindowDetect class not registered (extension not loaded)")
	else:
		var wd := WindowDetect.new()
		lines.append("is_available=%s  requires_permission=%s" % [wd.is_available(), wd.requires_permission()])
		var all = wd.get_window_rects()
		lines.append("get_window_rects -> %d windows" % all.size())
		for r in all:
			lines.append("  %s pid=%d layer=%d rect=%s" % [r["owner"], r["pid"], r["layer"], str(r["rect"])])
		var self_pid := OS.get_process_id()
		var others = wd.get_window_rects_excluding(self_pid)
		lines.append("get_window_rects_excluding(self=%d) -> %d windows" % [self_pid, others.size()])
	var text := "\n".join(lines)
	print(text)
	var f := FileAccess.open("user://out.txt", FileAccess.WRITE)
	if f:
		f.store_string(text); f.close()
	get_tree().quit()
