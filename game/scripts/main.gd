extends Node2D
## 0단계 시험판: 배경, 새, 뷰파인더와 셔터, 도감, 시험용 설정.
## 배경은 서식지마다 세로형·정사각형·가로형 세 벌이고, 화면 비율에 가장 가까운 벌을 화면에 꽉 차게 그린다
## (결정 기록 2026-10-22). 화면은 고정이고 밀어서 둘러보지 않는다. 회전·접기·창 크기가 바뀌면 벌을 다시 고른다.
## 장면 좌표 단위는 배경 칸이고, 카메라 확대 배율이 곧 '배경 한 칸 = 몇 화소'다.

const HABITAT := "res://assets/habitats/urban_river_park"
const CAPTURE_SHARE := 0.7                       # 새 그림의 70% 이상이 뷰파인더 안이면 찍힌 것

enum Drag { NONE, FINDER }

var background: Sprite2D
var birds_layer: Node2D
var camera: Camera2D
var sharp_mat: ShaderMaterial        # 새와 화면 그림이 함께 쓰는 '칸 경계 섞기' 재질
var db: SpeciesDB
var collection: Collection
var spawner: BirdSpawner
var capture_ui: CanvasLayer
var dex_ui: CanvasLayer
var debug_ui: CanvasLayer
var set_sizes := {}                 # 벌 이름 → 장면 크기(칸)
var set_perches := {}               # 벌 이름 → Perches
var scene_set := ""                 # 지금 쓰는 벌
var scene_cells := Vector2(240.0, 480.0)
var view_px := Vector2.ONE
var view_cells := Vector2(216.0, 480.0)
var bg_px := 5.0                    # 배경 한 칸 = 화면 몇 화소
var drag := Drag.NONE
var capture_left := -1


func _ready() -> void:
	sharp_mat = ShaderMaterial.new()
	sharp_mat.shader = preload("res://shaders/sharp_sprite.gdshader")
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
	spawner.setup(self, birds_layer, db, sharp_mat)
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

	capture_ui = preload("res://scripts/ui/capture_ui.gd").new()
	add_child(capture_ui)
	capture_ui.setup(self)
	capture_ui.shutter_pressed.connect(_on_shutter)
	capture_ui.dex_pressed.connect(_open_dex)

	dex_ui = preload("res://scripts/ui/dex_ui.gd").new()
	add_child(dex_ui)
	dex_ui.setup(self, db, collection, sharp_mat)

	debug_ui = preload("res://scripts/ui/debug_ui.gd").new()
	add_child(debug_ui)
	debug_ui.setup(self)

	get_tree().root.size_changed.connect(_on_resized)
	App.settings_changed.connect(_apply_settings)
	_on_resized()
	_apply_settings()
	capture_ui.set_dex_count(collection.found_count(), db.list.size())

	if App.args.has("prewarm"):
		spawner.prewarm()
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


## 지금 화면에 보이는 장면 범위 (배경 칸).
func view_rect() -> Rect2:
	return Rect2(camera.position - view_cells * 0.5, view_cells)


## 새가 내려앉을 수 있는 장면 범위: 보이는 범위에서 위·아래 화면 요소(셔터 줄 등)에 가린 곳을 뺀다.
## 그래야 앉은 새를 늘 뷰파인더로 찍을 수 있다.
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
	bg_px = Layout.cover_px(view_px, scene_cells)
	view_cells = Layout.window_cells(view_px, bg_px)
	camera.zoom = Vector2(bg_px, bg_px)
	_place_camera()
	capture_ui.on_resized()
	dex_ui.on_resized()
	debug_ui.on_resized()
	if changed:
		spawner.reseat()   # 회전·접기로 벌이 바뀌면 앉아 있던 새를 새 장면에 다시 앉힌다


func _apply_settings() -> void:
	background.set_evening(float(App.settings["evening"]))
	background.set_smooth(bool(App.settings["smooth_edges"]))
	sharp_mat.set_shader_parameter("smooth_edges", bool(App.settings["smooth_edges"]))
	dex_ui.shadow_mat.set_shader_parameter("smooth_edges", bool(App.settings["smooth_edges"]))
	# 임시: 저녁에는 새도 배경처럼 조금 물들인다 (새 색표가 생기면 바꾼다)
	birds_layer.modulate = Color.WHITE.lerp(Color(0.86, 0.76, 0.70), float(App.settings["evening"]))
	_place_camera()


## 카메라는 장면 가운데에 고정한다. 비율이 조금 달라 남는 만큼은 양쪽 가장자리를 똑같이 자른다.
func _place_camera() -> void:
	var step := 1.0 if bool(App.settings["snap_motion"]) else pixel_step()
	camera.position = Layout.snapped_center(scene_cells * 0.5, view_cells, step)


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
		capture_ui.set_dex_count(collection.found_count(), db.list.size())
	capture_ui.show_results(results, sharp_mat)


func _open_dex() -> void:
	dex_ui.open()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:   # 안드로이드 뒤로 가기: 열린 창부터 닫는다
		if not dex_ui.back() and not debug_ui.back():
			get_tree().quit()


## 뷰파인더 조작: 뷰파인더를 잡고 끌면 따라오고, 빈 곳을 누르면 그 자리로 와서 끄는 대로 따라온다.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not capture_ui.finder_hit(event.position):
				capture_ui.move_finder_to(event.position)
				capture_ui.hide_hint()
			drag = Drag.FINDER
		else:
			drag = Drag.NONE
	elif event is InputEventMouseMotion and drag == Drag.FINDER:
		capture_ui.move_finder_by(event.relative)
		capture_ui.hide_hint()


func _process(_delta: float) -> void:
	if capture_left > 0:
		capture_left -= 1
		if App.args.has("shoot") and capture_left == 25:
			_aim_and_shoot()
		if capture_left == 0:
			_capture()


## 화면 캡처용(--shoot): 앉아 있는 새 하나에 뷰파인더를 맞추고 셔터를 누른다.
func _aim_and_shoot() -> void:
	for b in spawner.active_birds():
		if b.state == Bird.State.PERCHED:
			var c := b.drawn_rect().get_center()
			var screen := (c - (camera.position - view_cells * 0.5)) * bg_px
			capture_ui.move_finder_to(screen)
			break
	_on_shutter()


func _capture() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(String(App.args["capture"]))
	get_tree().quit()
