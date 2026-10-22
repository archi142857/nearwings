extends CanvasLayer
## 도감: 0단계 10칸 격자. 찾은 새는 그림과 이름, 못 찾은 칸은 실루엣과 '???'.
## 찾은 새를 누르면 자세히 본다. 열 수는 화면 너비에 따라 짝수로 정한다(폴더블 접는 선에서 깔끔하게 나뉘게).

const SEASON := {"R": "텃새", "S": "여름철새", "W": "겨울철새", "P": "나그네새"}

var main: Node
var dens := 1.0
var db: SpeciesDB
var collection: Collection
var sharp_mat: ShaderMaterial
var shadow_mat: ShaderMaterial   # 못 찾은 새: 같은 셰이더로 모양만 한 색
var root: Panel
var title: Label
var close_btn: Button
var scroll: ScrollContainer
var grid: GridContainer
var detail: PanelContainer
var detail_box: VBoxContainer


func dp(v: float) -> int:
	return UiStyle.dp(v, dens)


func setup(main_node: Node, species_db: SpeciesDB, coll: Collection, mat: ShaderMaterial) -> void:
	main = main_node
	db = species_db
	collection = coll
	sharp_mat = mat
	shadow_mat = mat.duplicate()
	shadow_mat.set_shader_parameter("silhouette", 1.0)
	layer = 20
	dens = App.density()

	root = Panel.new()
	root.theme = UiStyle.theme(dens)
	root.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.PAPER, 0, 0))
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	title = UiStyle.label("", dp(20))
	root.add_child(title)
	close_btn = Button.new()
	close_btn.text = "닫기"
	close_btn.custom_minimum_size = Vector2(dp(72), dp(48))
	close_btn.pressed.connect(close)
	root.add_child(close_btn)

	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	grid = GridContainer.new()
	grid.add_theme_constant_override("h_separation", dp(10))
	grid.add_theme_constant_override("v_separation", dp(10))
	scroll.add_child(grid)

	detail = PanelContainer.new()
	var sb := UiStyle.box(UiStyle.PAPER, dp(16), dp(18))
	sb.border_color = UiStyle.LINE
	sb.set_border_width_all(maxi(1, dp(1)))
	detail.add_theme_stylebox_override("panel", sb)
	detail_box = VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", dp(8))
	detail.add_child(detail_box)
	detail.visible = false
	root.add_child(detail)

	visible = false


func is_open() -> bool:
	return visible


func open() -> void:
	visible = true
	detail.visible = false
	refresh()


func close() -> void:
	visible = false
	detail.visible = false


## 뒤로 가기: 자세히 보기가 열려 있으면 그것만 닫는다. 닫은 것이 있으면 true.
func back() -> bool:
	if detail.visible:
		detail.visible = false
		return true
	if visible:
		close()
		return true
	return false


func on_resized() -> void:
	if not visible:
		return
	_layout()


func refresh() -> void:
	title.text = "도감 %d/%d" % [collection.found_count(), db.list.size()]
	for c in grid.get_children():
		c.queue_free()
	var cols := _columns()
	grid.columns = cols
	var card_w := _card_width(cols)
	for sp in db.list:
		grid.add_child(_card(sp, card_w))
	_layout()


func _columns() -> int:
	var w_dp: float = main.view_px.x / dens
	var n := int(w_dp / 150.0)
	n -= n % 2
	return clampi(n, 2, 8)


func _card_width(cols: int) -> float:
	var inner: float = main.view_px.x - _insets_h() - dp(16) * 2
	return floorf((inner - dp(10) * (cols - 1)) / cols)


func _insets_h() -> float:
	var ins := UiStyle.insets()
	return ins.x + ins.z


func _layout() -> void:
	var vs: Vector2 = main.view_px
	var ins := UiStyle.insets()
	root.position = Vector2.ZERO
	root.size = vs
	var m := float(dp(16))
	title.size = title.get_combined_minimum_size()
	close_btn.size = close_btn.get_combined_minimum_size()
	var top := ins.y + m
	close_btn.position = Vector2(vs.x - ins.z - m - close_btn.size.x, top)
	title.position = Vector2(ins.x + m, top + (close_btn.size.y - title.size.y) * 0.5)
	var grid_top := top + close_btn.size.y + m
	scroll.position = Vector2(ins.x + m, grid_top)
	scroll.size = Vector2(vs.x - ins.x - ins.z - m * 2, vs.y - grid_top - ins.w - m)
	if detail.visible:
		_place_detail()


## 새마다 칸에 맞게 키우되, 가장 큰 새의 배율의 2배를 넘지 않게 한다.
## 그래서 작은 새도 잘 보이면서 큰 새·작은 새의 크기 차이가 어느 정도 남는다.
func _card_scale(tex_size: Vector2, card_w: float, pic_h: float) -> float:
	var biggest := Vector2.ZERO
	for sp in db.list:
		biggest = biggest.max(SpeciesDB.sprite_size(sp, "stand"))
	var area := Vector2(card_w - dp(16), pic_h)
	var shared := minf(area.x / biggest.x, area.y / biggest.y)
	var fit := minf(area.x / tex_size.x, area.y / tex_size.y)
	return minf(fit, shared * 2.0)


func _card(sp: Dictionary, card_w: float) -> Button:
	var found := collection.is_found(sp["id"])
	var card_h := card_w * 0.82
	var label_h := float(dp(30))
	var pic_h := card_h - dp(16) - label_h
	var b := Button.new()
	b.custom_minimum_size = Vector2(card_w, card_h)
	b.disabled = not found
	var pic := TextureRect.new()
	pic.texture = sp["tex"]["stand"]
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_SCALE
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	pic.material = sharp_mat if found else shadow_mat
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex_size := Vector2(pic.texture.get_size())
	pic.size = (tex_size * _card_scale(tex_size, card_w, pic_h)).round()
	pic.position = Vector2(round((card_w - pic.size.x) * 0.5), round(dp(8) + pic_h - pic.size.y))   # 발을 같은 줄에 맞춘다
	b.add_child(pic)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.position = Vector2(dp(8), dp(12) + pic_h)
	box.size = Vector2(card_w - dp(16), label_h)
	b.add_child(box)
	var nl := UiStyle.label(sp["ko"] if found else "???", dp(14))
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(nl)
	b.pressed.connect(func() -> void: show_detail(sp))
	return b


func show_detail(sp: Dictionary) -> void:
	for c in detail_box.get_children():
		c.queue_free()
	var e := collection.entry(sp["id"])
	var pic := TextureRect.new()
	pic.texture = sp["tex"]["stand"]
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	pic.material = sharp_mat
	var w: float = minf(main.view_px.x * 0.7, dp(360))
	pic.custom_minimum_size = Vector2(w, w * 0.62)
	detail_box.add_child(pic)
	detail_box.add_child(UiStyle.label(sp["ko"], dp(22)))
	detail_box.add_child(UiStyle.label("%s · %s" % [sp["en"], sp["sci"]], dp(12), UiStyle.BEIGE[6]))
	var size_word := "키" if sp["id"] == "ardea_cinerea" else "몸길이"
	var length := float(sp["length_cm"])
	var length_text := str(int(length)) if is_equal_approx(length, roundf(length)) else "%.1f" % length
	detail_box.add_child(UiStyle.label("%s 약 %scm · %s" % [size_word, length_text, SEASON.get(sp["season"], "")]))
	if not e.is_empty():
		detail_box.add_child(UiStyle.label("처음 찍은 날 %s · %d번 찍음" % [e["first"], int(e["count"])]))
	var close := Button.new()
	close.text = "닫기"
	close.custom_minimum_size.y = dp(48)
	close.pressed.connect(func() -> void: detail.visible = false)
	detail_box.add_child(close)
	detail.visible = true
	await get_tree().process_frame
	_place_detail()


func _place_detail() -> void:
	var vs: Vector2 = main.view_px
	detail.size = detail.get_combined_minimum_size()
	detail.position = ((vs - detail.size) * 0.5).round()
