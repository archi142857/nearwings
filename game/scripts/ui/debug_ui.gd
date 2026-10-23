extends CanvasLayer
## 시험용 화면 요소: FPS와 가장 느린 프레임, 설정 버튼과 설정 창.
## 크기는 dp로 잡는다(1dp = App.density() 화소). 그래서 기기가 달라도 손가락에 닿는 크기가 같다.

var main: Node
var dens := 1.0
var root: Control
var fps_label: Label
var gear: Button
var panel: PanelContainer
var info_label: Label
var frame_ms: Array[float] = []
var acc := 0.0


func dp(v: float) -> int:
	return UiStyle.dp(v, dens)


func setup(main_node: Node) -> void:
	main = main_node
	layer = 10
	dens = App.density()
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiStyle.theme(dens)
	add_child(root)

	fps_label = UiStyle.label("", dp(11))
	fps_label.add_theme_stylebox_override("normal", UiStyle.box(Color(UiStyle.PAPER, 0.85), dp(8), dp(6)))
	root.add_child(fps_label)

	gear = Button.new()
	gear.text = "설정"
	gear.custom_minimum_size = Vector2(dp(64), dp(48))
	gear.pressed.connect(_toggle_panel)
	root.add_child(gear)

	_build_panel()
	panel.visible = App.args.has("panel")   # 화면 캡처에서 설정 창까지 보려면 --panel
	visible = bool(App.settings["show_ui"])
	App.settings_changed.connect(_on_settings)


func _process(delta: float) -> void:
	frame_ms.append(delta * 1000.0)
	if frame_ms.size() > 300:
		frame_ms.pop_front()
	acc += delta
	if acc >= 0.5:
		acc = 0.0
		var worst := 0.0
		for v in frame_ms:
			worst = maxf(worst, v)
		var hour: float = main.clock_hour
		fps_label.text = "%d fps · 가장 느린 프레임 %d ms · %s · %s %s" % [Engine.get_frames_per_second(), int(round(worst)),
			Layout.SET_LABELS.get(main.scene_set, ""), TimeOfDay.format(hour), TimeOfDay.LABELS[TimeOfDay.phase(hour)]]
		fps_label.size = fps_label.get_combined_minimum_size()
		if panel.visible:
			_update_info()


func on_resized() -> void:
	var vs: Vector2 = main.view_px
	root.position = Vector2.ZERO
	root.size = vs
	var ins := UiStyle.insets()
	var m := float(dp(10))
	fps_label.size = fps_label.get_combined_minimum_size()
	fps_label.position = Vector2(ins.x + m, ins.y + m)
	gear.size = gear.get_combined_minimum_size()
	gear.position = Vector2(vs.x - ins.z - m - gear.size.x, ins.y + m)
	_place_panel()


## 뒤로 가기: 설정 창이 열려 있으면 닫는다. 닫은 것이 있으면 true.
func back() -> bool:
	if panel.visible:
		panel.visible = false
		return true
	return false


func _place_panel() -> void:
	var vs: Vector2 = main.view_px
	var ins := UiStyle.insets()
	panel.size = panel.get_combined_minimum_size()
	var x := vs.x - ins.z - dp(10) - panel.size.x
	var y := gear.position.y + gear.size.y + dp(8)
	panel.position = Vector2(maxf(dp(4), x), minf(y, maxf(dp(4), vs.y - panel.size.y - dp(4))))


func _toggle_panel() -> void:
	panel.visible = not panel.visible
	if panel.visible:
		_update_info()
		_place_panel()


func _build_panel() -> void:
	panel = PanelContainer.new()
	var sb := UiStyle.box(Color(UiStyle.PAPER, 0.97), dp(14), dp(14))
	sb.border_color = UiStyle.LINE
	sb.set_border_width_all(maxi(1, dp(1)))
	panel.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", dp(8))
	panel.add_child(box)

	box.add_child(UiStyle.label("시험용 설정", dp(15)))

	var ratio_row := HBoxContainer.new()
	ratio_row.add_theme_constant_override("separation", dp(6))
	var rl := UiStyle.label("배경 칸")
	rl.custom_minimum_size.x = dp(64)
	ratio_row.add_child(rl)
	var group := ButtonGroup.new()
	for r in [1.0, 1.25]:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.text = "%s배" % ("1.0" if r == 1.0 else "1.25")
		b.button_pressed = is_equal_approx(float(App.settings["bg_ratio"]), r)
		b.custom_minimum_size = Vector2(dp(72), dp(44))
		b.pressed.connect(func() -> void: App.set_setting("bg_ratio", r))
		ratio_row.add_child(b)
	box.add_child(ratio_row)

	box.add_child(_toggle("칸 경계 섞기", "smooth_edges"))
	box.add_child(_toggle("칸 단위로 움직이기", "snap_motion"))
	box.add_child(_toggle("소리 (시간대 섞기 시험 곡)", "sound"))

	info_label = UiStyle.label("", dp(11))
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.custom_minimum_size.x = dp(232)
	box.add_child(info_label)

	var close := Button.new()
	close.text = "닫기"
	close.custom_minimum_size.y = dp(44)
	close.pressed.connect(func() -> void: panel.visible = false)
	box.add_child(close)

	root.add_child(panel)


## 켜고 끄는 버튼. 기본 체크 스위치는 기기 배율을 따라 커지지 않아 손가락으로 누르기 어렵다.
func _toggle(title: String, key: String) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = bool(App.settings[key])
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size.y = dp(44)
	var paint := func(on: bool) -> void: b.text = "%s: %s" % [title, "켬" if on else "끔"]
	paint.call(b.button_pressed)
	b.toggled.connect(func(on: bool) -> void:
		paint.call(on)
		App.set_setting(key, on))
	return b


func _on_settings() -> void:
	visible = bool(App.settings["show_ui"])
	_update_info()


func _update_info() -> void:
	var vs: Vector2 = main.view_px
	var cells: Vector2 = main.view_cells
	var scene: Vector2 = main.scene_cells
	info_label.text = "배경 %s %d×%d칸 중 %d×%d칸이 보임 · 화면 %d×%d · 배경 한 칸 %.2f화소 · 새 한 칸 %.2f화소 · 1dp = %.2f화소 · %s" % [
		Layout.SET_LABELS.get(main.scene_set, ""), int(scene.x), int(scene.y), int(round(cells.x)), int(round(cells.y)),
		int(vs.x), int(vs.y), main.bg_px, main.bg_px * main.bird_cell(),
		dens, "폰 크기(세로 고정)" if App.is_phone_now() else "큰 화면(모든 방향)"]
	info_label.text += " · 시각 %s (기기 시계)" % TimeOfDay.format(main.clock_hour)
