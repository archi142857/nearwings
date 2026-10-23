extends Node2D
## 0단계 시험판: 로딩 화면, 배경, 새, 가방 메뉴, 뷰파인더와 셔터, 도감, 시험용 설정.
## 배경은 서식지마다 세로형·정사각형·가로형 세 벌이고, 화면 비율에 가장 가까운 벌을 화면에 꽉 차게 그린다
## (결정 기록 2026-10-22). 화면은 고정이고 밀어서 둘러보지 않는다. 회전·접기·창 크기가 바뀌면 벌을 다시 고른다.
## 배경과 새 빛깔은 시간대(새벽·낮·저녁·밤)를 따른다. 시간은 5분에 하루가 지나거나(기본) 기기 시계를 따른다(시험용 설정).
## 기본 화면에는 뷰파인더와 셔터가 없다. 위로 밀어 가방을 열고 카메라나 쌍안경을 꺼내면 나온다(0단계는 둘이 같다).
## 장면 좌표 단위는 배경 칸이고, 카메라 확대 배율이 곧 '배경 한 칸 = 몇 화소'다.

const HABITAT := "res://assets/habitats/urban_river_park"
const CAPTURE_SHARE := 0.7                       # 새 그림의 70% 이상이 뷰파인더 안이면 찍힌 것
const LOOK_DARKEN := 0.16                        # 가방을 다 열었을 때 공원·바닥·새가 어두워지는 정도 (배치값 focus_pull)
const LOOK_DESAT := 0.18                         # 그때 채도를 빼는 정도
const BIRD_BLUR := 0.9                           # 그때 새를 흐리는 정도 (새 칸: 폰 3.6화소 ÷ 4화소)
const DRAG_DP := 10.0                            # 이만큼 움직여야 '밀기'로 본다
const EDGE_DP := 24.0                            # 맨 아래 가장자리: 안드로이드·iOS 홈 제스처 자리라 위로 밀기를 받지 않는다
const CAPTURE_TOOLS := ["camera", "binoculars"]  # 뷰파인더와 셔터를 쓰는 도구 (0단계는 둘이 같다)
const SPLASH := preload("res://scripts/ui/splash.gd")

enum Touch { NONE, PENDING, FINDER, OPEN_DRAG, CLOSE_DRAG, TOOL }

var background: Sprite2D
var birds_layer: Node2D
var camera: Camera2D
var sharp_mat: ShaderMaterial        # 화면 그림(가방·도감 등)이 함께 쓰는 '칸 경계 섞기' 재질
var bird_mat: ShaderMaterial         # 공원의 새: 같은 셰이더에 가방을 열 때 흐림·채도 빼기를 더한다
var db: SpeciesDB
var collection: Collection
var spawner: BirdSpawner
var capture_ui: CanvasLayer
var bag: CanvasLayer
var dex_ui: CanvasLayer
var debug_ui: CanvasLayer
var splash: CanvasLayer = null      # 로딩 화면 (켤 때 한 번, 끝나면 스스로 사라진다)
var set_sizes := {}                 # 벌 이름 → 장면 크기(칸)
var set_perches := {}               # 벌 이름 → Perches
var scene_set := ""                 # 지금 쓰는 벌
var scene_cells := Vector2(240.0, 480.0)
var view_px := Vector2.ONE
var view_cells := Vector2(216.0, 480.0)
var bg_px := 5.0                    # 배경 한 칸 = 화면 몇 화소
var cam_base := Vector2.ZERO        # 공원을 볼 때의 화면 가운데 (가방을 들여다보면 카메라가 여기서 내려간다)
var tool := ""                      # 손에 든 도구: "", camera, binoculars
var touch := Touch.NONE
var touch_start := Vector2.ZERO
var touch_tool := ""
var capture_left := -1
var clock_hour := 12.0              # 게임 시각 (0~24시)
var clock_start := 12.0             # 빠른 시간이 시작한 시각
var clock_elapsed := 0.0            # 빠른 시간이 시작하고 지난 초
var clock_frozen := false           # --hour: 그 시각에 멈춤 (화면 캡처·시험용)
var time_mode := ""


func _ready() -> void:
	# 로딩 화면을 먼저 올리고 첫 장면을 바로 그린다(시스템 스플래시와 같은 그림). 게임은 그 뒤에서 만든다
	if SPLASH.wanted():
		splash = SPLASH.new()
		add_child(splash)
		splash.draw_now()
	sharp_mat = ShaderMaterial.new()
	sharp_mat.shader = preload("res://shaders/sharp_sprite.gdshader")
	bird_mat = sharp_mat.duplicate()
	background = preload("res://scripts/background.gd").new()
	add_child(background)
	background.setup(HABITAT)
	set_sizes = background.set_sizes()
	for s in set_sizes:
		var p := Perches.new()
		p.load_file("%s/%s/perches.json" % [HABITAT, s])
		set_perches[s] = p

	birds_layer = Node2D.new()
	birds_layer.y_sort_enabled = true
	add_child(birds_layer)

	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()

	db = SpeciesDB.new()
	db.load_file("res://data/species.json")
	spawner = BirdSpawner.new()
	spawner.setup(self, birds_layer, db, bird_mat)
	add_child(spawner)

	collection = Collection.new()
	var save_path := String(App.args.get("save", Collection.DEFAULT_PATH))
	if App.args.has("fresh"):   # 화면 캡처용: 저장 파일을 읽지 않고 빈 도감으로 시작
		collection.path = save_path
	else:
		collection.load_file(save_path)
	if App.args.has("found"):   # 화면 캡처용: 찾은 것으로 쳐 둘 종 (저장하지 않는다)
		for id in String(App.args["found"]).split(","):
			collection.register(id, Collection.today())

	bag = preload("res://scripts/ui/bag_menu.gd").new()
	add_child(bag)
	bag.setup(self, sharp_mat)
	bag.chosen.connect(_on_tool_chosen)
	bag.closed.connect(_on_bag_closed)

	capture_ui = preload("res://scripts/ui/capture_ui.gd").new()
	add_child(capture_ui)
	capture_ui.setup(self)
	capture_ui.shutter_pressed.connect(_on_shutter)

	dex_ui = preload("res://scripts/ui/dex_ui.gd").new()
	add_child(dex_ui)
	dex_ui.setup(self, db, collection, sharp_mat)

	debug_ui = preload("res://scripts/ui/debug_ui.gd").new()
	add_child(debug_ui)
	debug_ui.setup(self)

	# 시간: 처음에는 기기 시계의 지금 시각에서 시작한다
	if App.args.has("hour"):
		clock_start = float(App.args["hour"])
		clock_frozen = true
	else:
		clock_start = TimeOfDay.real_hour()
	clock_hour = clock_start
	time_mode = String(App.settings["time_mode"])

	get_tree().root.size_changed.connect(_on_resized)
	App.settings_changed.connect(_apply_settings)
	_on_resized()
	_apply_settings()

	if App.args.has("prewarm"):
		spawner.prewarm()
	if String(App.args.get("tool", "")) in CAPTURE_TOOLS:   # 화면 캡처·시험용: 도구를 들고 시작
		_hold(String(App.args["tool"]))
	if App.args.has("dex"):
		_open_dex()
		if App.args.has("detail"):
			dex_ui.show_detail(db.by_id[String(App.args["detail"])])
	if App.args.has("capture"):
		capture_left = int(App.args.get("frames", "40"))
	if App.args.has("selftest"):
		var t: Node = preload("res://scripts/selftest.gd").new()
		add_child(t)
		t.run(self)


## 새 한 칸이 배경 몇 칸인지 (배경 칸이 1.25배면 0.8).
func bird_cell() -> float:
	return 1.0 / float(App.settings["bg_ratio"])


## 화면 한 화소가 배경 몇 칸인지.
func pixel_step() -> float:
	return 1.0 / bg_px


## 공원을 볼 때 화면에 보이는 장면 범위 (배경 칸). 가방을 들여다보는 동안에도 같다(새가 오가는 기준).
func view_rect() -> Rect2:
	return Rect2(cam_base - view_cells * 0.5, view_cells)


## 새가 내려앉을 수 있는 장면 범위: 보이는 범위에서 위·아래 화면 요소(셔터 줄 등)에 가린 곳을 뺀다.
## 그래야 앉은 새를 늘 뷰파인더로 찍을 수 있다. 뷰파인더와 셔터가 숨어 있어도 같은 범위다(기기마다 확률이 같게).
func play_rect() -> Rect2:
	var v := view_rect()
	var band: Vector2 = capture_ui.play_band_px() / bg_px
	return Rect2(v.position.x, v.position.y + band.x, v.size.x, maxf(1.0, band.y - band.x))


## 이 화면에 쓸 벌: 실행 인자 --set이 있으면 그것, 없으면 비율이 가장 가까운 것.
func pick_set(size_px: Vector2) -> String:
	var forced := String(App.args.get("set", ""))
	if set_sizes.has(forced):
		return forced
	return Layout.choose_set(size_px, set_sizes)


func _on_resized() -> void:
	view_px = get_viewport().get_visible_rect().size
	var chosen := pick_set(view_px)
	var changed := chosen != scene_set
	if changed:
		scene_set = chosen
		background.use_set(chosen)
		scene_cells = set_sizes[chosen]
		spawner.use_perches(set_perches[chosen])
		_apply_time()
	bg_px = Layout.cover_px(view_px, scene_cells)
	view_cells = Layout.window_cells(view_px, bg_px)
	camera.zoom = Vector2(bg_px, bg_px)
	_place_camera()
	bag.on_resized()
	capture_ui.on_resized()
	dex_ui.on_resized()
	debug_ui.on_resized()
	if changed:
		spawner.reseat()   # 회전·접기로 벌이 바뀌면 앉아 있던 새를 새 장면에 다시 앉힌다


func _apply_settings() -> void:
	background.set_smooth(bool(App.settings["smooth_edges"]))
	sharp_mat.set_shader_parameter("smooth_edges", bool(App.settings["smooth_edges"]))
	bird_mat.set_shader_parameter("smooth_edges", bool(App.settings["smooth_edges"]))
	dex_ui.shadow_mat.set_shader_parameter("smooth_edges", bool(App.settings["smooth_edges"]))
	bag.shadow_mat.set_shader_parameter("smooth_edges", bool(App.settings["smooth_edges"]))
	var mode := String(App.settings["time_mode"])
	if mode != time_mode:
		time_mode = mode
		if mode == "fast":   # 빠른 시간으로 바꾸면 지금 시각에서 이어서 흐른다
			clock_start = clock_hour
			clock_elapsed = 0.0
	_place_camera()


## 시각을 흐르게 하고, 배경과 새 빛깔을 그 시각에 맞춘다.
func _tick_clock(delta: float) -> void:
	if not clock_frozen:
		if time_mode == "real":
			clock_hour = TimeOfDay.real_hour()
		else:
			clock_elapsed += delta
			clock_hour = TimeOfDay.fast_hour(clock_start, clock_elapsed)
	_apply_time()


## 가방 메뉴를 여는 만큼(흐림 정도 a) 공원·바닥·새를 흐리고 채도를 빼고 어둡게 한다(배치값 focus_pull).
## 가방·도구·이름표는 밤에도 낮 색 그대로 둔다(결정 기록 2026-10-22).
func _apply_time() -> void:
	background.set_time(clock_hour)
	var a: float = bag.focus() if bag else 0.0
	var dark := 1.0 - LOOK_DARKEN * a
	background.modulate = Color(dark, dark, dark)
	background.set_focus(a, LOOK_DESAT * a)
	birds_layer.modulate = TimeOfDay.bird_tint(clock_hour) * Color(dark, dark, dark)   # 임시: 새도 배경처럼 조금 물들인다
	bird_mat.set_shader_parameter("desat", LOOK_DESAT * a)
	bird_mat.set_shader_parameter("blur", BIRD_BLUR * a)


## 카메라는 장면 가운데에 고정한다. 비율이 조금 달라 남는 만큼은 양쪽 가장자리를 똑같이 자른다.
## 가방을 들여다보는 만큼(bag.look) 화면 높이만큼 내려가 발밑 바닥을 본다.
func _place_camera() -> void:
	var step := 1.0 if bool(App.settings["snap_motion"]) else pixel_step()
	cam_base = Layout.snapped_center(scene_cells * 0.5, view_cells, step)
	# 발밑 바닥은 보이는 공원 바로 아래 줄에서 시작한다. 다 내려가면 화면에 바닥만 보인다
	var ground_top := ceilf(cam_base.y + view_cells.y * 0.5 - 0.001)
	background.set_ground_top(ground_top)
	var drop := ground_top - (cam_base.y - view_cells.y * 0.5)   # 화면 높이 (+1칸 미만)
	var look: float = bag.look if bag else 0.0
	camera.position = cam_base + Vector2(0.0, snappedf(look * drop, step))


func _on_shutter() -> void:
	var frame: Rect2 = capture_ui.finder_world_rect()
	var results := []
	for b in spawner.active_birds():
		var r := b.drawn_rect()
		if r.get_area() > 0.0 and r.intersection(frame).get_area() / r.get_area() >= CAPTURE_SHARE:
			results.append([b.sp, collection.register(b.sp["id"], Collection.today())])
	capture_ui.flash_now()
	if not results.is_empty():
		collection.save()
	capture_ui.show_results(results, sharp_mat)


func _open_dex() -> void:
	dex_ui.open()


## 가방에서 도구를 골랐다. 도감은 가방 위에 열고, 카메라·쌍안경은 들고 공원으로 돌아간다.
func _on_tool_chosen(id: String) -> void:
	if id == "dogam":
		_open_dex()
	elif id in CAPTURE_TOOLS:
		tool = id
		bag.close()


func _on_bag_closed() -> void:
	capture_ui.set_active(tool in CAPTURE_TOOLS)
	capture_ui.set_hidden(false)


## 도구를 든다(셔터와 뷰파인더가 나온다). ""이면 넣는다.
func _hold(id: String) -> void:
	tool = id
	capture_ui.set_active(id in CAPTURE_TOOLS)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:   # 안드로이드 뒤로 가기: 열린 것부터 닫고, 든 도구를 넣고, 없으면 끝낸다
		if dex_ui.back() or debug_ui.back() or bag.back():
			return
		if tool != "":
			_hold("")
			return
		get_tree().quit()


## 손가락 조작.
##   기본 화면: 위로 밀면 가방(맨 아래 가장자리에서 시작한 것은 받지 않는다). 도구를 들고 있으면
##   뷰파인더를 잡고 끌거나, 빈 곳을 짧게 누르거나(그 자리로), 옆·아래로 끌어 뷰파인더를 옮긴다.
##   열린 가방: 도구를 누르면 고른다. 아래로 밀거나 위쪽 흐린 바닥을 누르면 닫힌다.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_touch_down(event.position)
		else:
			_touch_up(event.position)
	elif event is InputEventMouseMotion and touch != Touch.NONE:
		_touch_move(event.position, event.relative)


func _touch_down(p: Vector2) -> void:
	touch_start = p
	touch_tool = ""
	if bag.is_open():
		touch_tool = bag.tool_at(p)
		if touch_tool != "":
			bag.press(touch_tool)
			touch = Touch.TOOL
			return
		touch = Touch.PENDING
	elif bag.is_closed():
		if tool in CAPTURE_TOOLS and capture_ui.finder_hit(p):
			touch = Touch.FINDER
			capture_ui.hide_hint()
		else:
			touch = Touch.PENDING
	else:
		touch = Touch.NONE   # 가방이 움직이는 중


func _touch_move(p: Vector2, rel: Vector2) -> void:
	var d := p - touch_start
	var far := d.length() > UiStyle.dp(DRAG_DP, App.density())
	match touch:
		Touch.FINDER:
			capture_ui.move_finder_by(rel)
		Touch.OPEN_DRAG:
			bag.drag_to(-d.y / view_px.y)
		Touch.CLOSE_DRAG:
			bag.drag_to(1.0 - d.y / view_px.y)
		Touch.TOOL:
			if far:   # 도구에서 손가락이 벗어나면 누른 것을 무른다
				bag.release(false)
				touch = Touch.PENDING
				_touch_move(p, rel)
		Touch.PENDING:
			if not far:
				return
			var vertical := absf(d.y) > absf(d.x)
			if bag.is_closed():
				var from_edge := touch_start.y > view_px.y - UiStyle.insets().w - UiStyle.dp(EDGE_DP, App.density())
				if vertical and d.y < 0.0 and not from_edge:
					touch = Touch.OPEN_DRAG
					capture_ui.set_hidden(true)   # 뷰파인더와 셔터는 누를 수 없고, 밀기 첫 15% 동안 사라진다
					bag.begin_drag()
					bag.drag_to(-d.y / view_px.y)
				elif tool in CAPTURE_TOOLS:
					touch = Touch.FINDER   # 빈 곳에서 옆·아래로 끌면 뷰파인더가 그 자리로 와서 따라온다
					capture_ui.move_finder_to(p)
					capture_ui.hide_hint()
				else:
					touch = Touch.NONE
			elif bag.is_open():
				if vertical and d.y > 0.0:
					touch = Touch.CLOSE_DRAG
					bag.begin_drag()
					bag.drag_to(1.0 - d.y / view_px.y)
				else:
					touch = Touch.NONE


func _touch_up(p: Vector2) -> void:
	match touch:
		Touch.TOOL:
			bag.release(bag.tool_at(p) == touch_tool)
		Touch.OPEN_DRAG:
			bag.end_drag(true)
		Touch.CLOSE_DRAG:
			bag.end_drag(false)
		Touch.PENDING:   # 짧게 눌렀다
			if bag.is_open():
				if p.y < bag.top_px():
					bag.close()   # 위쪽 흐린 바닥을 누르면 닫힌다
			elif bag.is_closed() and tool in CAPTURE_TOOLS:
				capture_ui.move_finder_to(p)
				capture_ui.hide_hint()
	touch = Touch.NONE


func _process(delta: float) -> void:
	_tick_clock(delta)
	_place_camera()
	if bag.is_busy() and not capture_ui.hidden:
		capture_ui.set_hidden(true)
	capture_ui.set_fade(bag.ui_alpha())
	if capture_left > 0:
		capture_left -= 1
		if App.args.has("shoot") and capture_left == 8:   # 찍고 나서 알림이 떠 있는 동안 화면을 찍는다
			_aim_and_shoot()
		if capture_left == 0:
			_capture()


## 화면 캡처용(--shoot): 앉아 있는 새 하나에 뷰파인더를 맞추고 셔터를 누른다.
func _aim_and_shoot() -> void:
	for b in spawner.active_birds():
		if b.state == Bird.State.PERCHED:
			var c := b.drawn_rect().get_center()
			capture_ui.move_finder_to((c - view_rect().position) * bg_px)
			break
	_on_shutter()


func _capture() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(String(App.args["capture"]))
	get_tree().quit()
