extends CanvasLayer
## 포착 화면: 뷰파인더, 셔터, 도감 버튼, 찍을 때 번쩍임, 결과 알림, 첫 안내.
## 뷰파인더는 화면에 붙어 있어 배경을 밀어도 그대로다. 끌어서 옮기거나, 빈 곳을 짧게 누르면 그 자리로 온다.
## 뷰파인더 크기는 배경 칸 기준(64×64칸)이라 기기가 달라도 새와의 크기 비가 같다.

signal shutter_pressed
signal dex_pressed

const VF_CELLS := 64.0
const SHUTTER_CELLS := 22.0

var main: Node
var dens := 1.0
var root: Control
var finder: Control
var finder_frac := Vector2(0.5, 0.45)   # 뷰파인더 가운데 (화면 비율)
var shutter: TextureButton
var dex_btn: Button
var flash: ColorRect
var toast: PanelContainer
var toast_box: VBoxContainer
var toast_tween: Tween
var flash_tween: Tween
var hint: Label


func dp(v: float) -> int:
	return UiStyle.dp(v, dens)


func setup(main_node: Node) -> void:
	main = main_node
	layer = 5
	dens = App.density()
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiStyle.theme(dens)
	add_child(root)

	finder = preload("res://scripts/ui/viewfinder.gd").new()
	finder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(finder)

	flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash)

	shutter = TextureButton.new()
	shutter.texture_normal = UiStyle.shutter_texture(false)
	shutter.texture_pressed = UiStyle.shutter_texture(true)
	shutter.ignore_texture_size = true
	shutter.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	shutter.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shutter.pressed.connect(func() -> void: shutter_pressed.emit())
	root.add_child(shutter)

	dex_btn = Button.new()
	dex_btn.custom_minimum_size = Vector2(dp(88), dp(48))
	dex_btn.pressed.connect(func() -> void: dex_pressed.emit())
	root.add_child(dex_btn)

	hint = UiStyle.label("괄호를 끌어 새를 넣고 셔터로 찍기")
	hint.add_theme_stylebox_override("normal", UiStyle.box(Color(UiStyle.PAPER, 0.9), dp(16), dp(10)))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint)

	toast = PanelContainer.new()
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UiStyle.box(Color(UiStyle.PAPER, 0.97), dp(14), dp(12))
	sb.border_color = UiStyle.LINE
	sb.set_border_width_all(maxi(1, dp(1)))
	toast.add_theme_stylebox_override("panel", sb)
	toast_box = VBoxContainer.new()
	toast_box.add_theme_constant_override("separation", dp(6))
	toast.add_child(toast_box)
	toast.visible = false
	root.add_child(toast)

	if App.args.has("vf"):
		var p: PackedStringArray = String(App.args["vf"]).split(",")
		finder_frac = Vector2(float(p[0]), float(p[1]))


func on_resized() -> void:
	var vs: Vector2 = main.view_px
	root.position = Vector2.ZERO
	root.size = vs
	flash.position = Vector2.ZERO
	flash.size = vs
	var ins := UiStyle.insets()
	var cell: float = main.bg_px
	finder.cell_px = cell
	var side := minf(VF_CELLS * cell, 0.8 * minf(vs.x, vs.y))
	finder.size = Vector2(side, side).round()
	# 셔터는 칸 느낌이 나게 정수 배로 키우되 손가락 크기(64dp)보다 작아지지 않게
	var k := maxf(round(cell), ceilf(dp(64) / SHUTTER_CELLS))
	shutter.size = Vector2.ONE * SHUTTER_CELLS * k
	shutter.position = Vector2(round((vs.x - shutter.size.x) * 0.5), vs.y - ins.w - dp(20) - shutter.size.y)
	dex_btn.size = dex_btn.get_combined_minimum_size()
	dex_btn.position = Vector2(ins.x + dp(16), shutter.position.y + (shutter.size.y - dex_btn.size.y) * 0.5)
	hint.size = hint.get_combined_minimum_size()
	hint.position = Vector2(round((vs.x - hint.size.x) * 0.5), shutter.position.y - dp(12) - hint.size.y)
	_place_finder()
	_place_toast()


## 새를 찍을 수 있는 화면 띠 (위·아래 화면 요소를 뺀 곳, 화면 화소): x = 위, y = 아래.
func play_band_px() -> Vector2:
	return Vector2(UiStyle.insets().y + dp(64), shutter.position.y - dp(8))


func _place_finder() -> void:
	var vs: Vector2 = main.view_px
	var band := play_band_px()
	var top := band.x
	var bottom := band.y
	var half := finder.size * 0.5
	var c := finder_frac * vs
	c.x = clampf(c.x, half.x + dp(4), vs.x - half.x - dp(4))
	c.y = clampf(c.y, top + half.y, maxf(top + half.y, bottom - half.y))
	finder.position = (c - half).round()
	finder.queue_redraw()


func _place_toast() -> void:
	var vs: Vector2 = main.view_px
	toast.size = toast.get_combined_minimum_size()
	toast.position = Vector2(round((vs.x - toast.size.x) * 0.5), UiStyle.insets().y + dp(60))


## 이 화면 점이 뷰파인더를 잡은 것인지 (손가락이라 조금 넉넉하게).
func finder_hit(p: Vector2) -> bool:
	return finder.get_rect().grow(dp(12)).has_point(p)


func move_finder_by(delta_px: Vector2) -> void:
	finder_frac += delta_px / main.view_px
	_place_finder()
	_clamp_frac()


func move_finder_to(p: Vector2) -> void:
	finder_frac = p / main.view_px
	_place_finder()
	_clamp_frac()


func _clamp_frac() -> void:
	finder_frac = (finder.position + finder.size * 0.5) / main.view_px


## 뷰파인더가 덮는 월드 범위 (배경 칸).
func finder_world_rect() -> Rect2:
	var cam_top_left: Vector2 = main.camera.position - main.view_cells * 0.5
	return Rect2(cam_top_left + finder.position / main.bg_px, finder.size / main.bg_px)


func set_dex_count(found: int, total: int) -> void:
	dex_btn.text = "도감 %d/%d" % [found, total]
	dex_btn.size = dex_btn.get_combined_minimum_size()


func hide_hint() -> void:
	hint.visible = false


func flash_now() -> void:
	if flash_tween:
		flash_tween.kill()
	flash.color = Color(1, 1, 1, 0.75)
	flash_tween = create_tween()
	flash_tween.tween_property(flash, "color:a", 0.0, 0.3)


## results: [[종 정보, {"new":, "count":}], ...]. 비어 있으면 빈 사진.
func show_results(results: Array, sharp_mat: Material) -> void:
	for c in toast_box.get_children():
		c.queue_free()
	if results.is_empty():
		toast_box.add_child(UiStyle.label("괄호 안에 새가 없어요"))
	for r in results:
		var sp: Dictionary = r[0]
		var res: Dictionary = r[1]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", dp(10))
		var pic := TextureRect.new()
		pic.texture = sp["tex"]["stand"]
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		pic.material = sharp_mat
		pic.custom_minimum_size = Vector2(dp(56), dp(40))
		row.add_child(pic)
		var text := "새로 찾았다! %s" % sp["ko"] if res["new"] else "%s · %d번째 사진" % [sp["ko"], int(res["count"])]
		var l := UiStyle.label(text, dp(15) if res["new"] else 0)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(l)
		toast_box.add_child(row)
	toast.visible = true
	toast.modulate.a = 0.0
	await get_tree().process_frame
	_place_toast()
	if toast_tween:
		toast_tween.kill()
	toast_tween = create_tween()
	toast_tween.tween_property(toast, "modulate:a", 1.0, 0.15)
	toast_tween.tween_interval(1.8)
	toast_tween.tween_property(toast, "modulate:a", 0.0, 0.35)
	toast_tween.tween_callback(func() -> void: toast.visible = false)
