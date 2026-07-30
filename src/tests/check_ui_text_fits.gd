extends SceneTree

## Headless check that no UI text is wider than the box that holds it.
##
## The pixel font is 6px per character at 1x and 12px at 2x, while every panel
## in the game was laid out against Godot's 16px default. A size that is one
## step too large silently runs past a panel edge, which is only visible by
## eye on the screen it happens to appear on. This walks the live tree on each
## route instead.
##
## Run:
##   godot --headless --path src --script res://tests/check_ui_text_fits.gd
##
## Exits non-zero when any string overflows.

const CANVAS := Vector2(800.0, 450.0)
## Buttons add left and right content margins on top of the text width.
const BUTTON_PADDING := 12.0

var _router: Node
var _failures: Array[String] = []
var _checked := 0
var _frames := 0
var _stage := 0


func _initialize() -> void:
	root.add_child(load("res://main.tscn").instantiate())


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 30:
		return false

	if _router == null:
		_router = root.find_child("SceneRouter", true, false)
		if _router == null:
			push_error("SceneRouter not found.")
			return true

	match _stage:
		0:
			_audit("title")
			_router.call("open_system_city")
		1:
			_audit("system_city")
			_router.call("open_builder_prototype")
		2:
			_audit("builder_prototype")
			_router.call("open_origin_builder")
		3:
			_audit("origin_builder")
			_router.call("open_chapter_select")
		4:
			_audit("chapter_select")
			_report()
			return true
	_stage += 1
	_frames = 0
	return false


func _audit(requested_route: String) -> void:
	# Some routes are gated on save state and quietly refuse to open, so the
	# scene actually on screen is reported rather than the one asked for.
	var host := root.find_child("SceneHost", true, false)
	var resident := "<none>"
	if host != null and host.get_child_count() > 0:
		resident = host.get_child(0).name
	var route := (
		requested_route
		if resident.to_lower().contains(requested_route.replace("_", ""))
		else "%s (resident: %s)" % [requested_route, resident]
	)

	for node in root.find_children("*", "Control", true, false):
		var control := node as Control
		if not control.is_visible_in_tree() or control.size.x <= 0.0:
			continue

		var text := ""
		var padding := 0.0
		if control is Label:
			var label := control as Label
			# Wrapped and clipped labels are allowed to be narrower than their
			# text; they degrade readably instead of spilling.
			if label.autowrap_mode != TextServer.AUTOWRAP_OFF or label.clip_text:
				continue
			text = label.text
		elif control is Button:
			text = (control as Button).text
			padding = BUTTON_PADDING
		else:
			continue
		if text.strip_edges().is_empty():
			continue

		var font: Font = control.get_theme_font("font")
		if font == null:
			continue
		var font_size := control.get_theme_font_size("font_size")
		_checked += 1

		if font_size % 10 != 0:
			_failures.append(
				"%s | %s | font_size %d is not a multiple of the native 10"
				% [route, control.name, font_size]
			)

		var widest := 0.0
		for line in text.split("\n"):
			widest = maxf(
				widest,
				font.get_string_size(
					line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
				).x
			)
		var needed := widest + padding
		if needed > control.size.x + 0.5:
			_failures.append(
				"%s | %s | '%s' needs %.0fpx in a %.0fpx box"
				% [route, control.name, text.split("\n")[0], needed, control.size.x]
			)

		var rect := control.get_global_rect()
		if rect.position.x < -0.5 or rect.end.x > CANVAS.x + 0.5:
			_failures.append(
				"%s | %s | spans x %.0f..%.0f, outside the %.0fpx canvas"
				% [route, control.name, rect.position.x, rect.end.x, CANVAS.x]
			)


func _report() -> void:
	print("[UI FIT] checked %d strings across %d route attempts" % [_checked, _stage + 1])
	if _failures.is_empty():
		print("[UI FIT] PASS")
		return
	for failure in _failures:
		print("[UI FIT] FAIL %s" % failure)
	print("[UI FIT] %d problem(s)" % _failures.size())
	quit(1)
