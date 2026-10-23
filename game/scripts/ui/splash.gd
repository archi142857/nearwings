extends CanvasLayer
## 로딩 화면 (자리와 시간표는 SplashPlan). 앱을 켤 때 한 번, 게임 위에 덮어 0.85초 동안 보이고 사라진다.
## 누르면 바로 넘어간다. 게임은 그동안 뒤에서 만들어지고 돌아간다(기다리는 시간을 늘리지 않는다).
##
## 첫 장면은 시스템 스플래시와 같은 그림이다. 내보내기 설정(splash_screen/disable_godot_boot_splash)으로
## 시스템 스플래시가 엔진이 다 뜰 때까지 남아 있게 하고, 여기서 _ready에 첫 장면을 바로 그려 둔다(draw_now).
## 그래서 시스템 스플래시가 걷히는 순간 같은 그림이 이미 화면에 있다.
## 노드 그리기는 다음 프레임으로 미뤄져 _ready에서 그려지지 않으므로 RenderingServer로 직접 그린다.
## 움직임은 게임 장면의 첫 프레임(셰이더를 처음 만드느라 느리다)이 지나고 나서 시작한다.
##
## 실행 인자: --nosplash(끔), --splash=<초>(그 시각에 멈춤, 화면 캡처용), --splash_record=<폴더>(초당 30장 저장하고 끝냄),
##   --lang=ko|en(이름 언어), --splash_live(--selftest에서도 그대로 띄움). --capture·--selftest로 돌릴 때는
##   이 인자들을 주지 않으면 나오지 않는다.

signal finished

const DATA_PATH := "res://assets/splash/splash.json"
const WAIT_FRAMES := 2          # 움직이기 전에 첫 장면으로 기다리는 프레임 (게임 첫 프레임이 지나도록)
const RECORD_FPS := 30.0

var data: Dictionary
var plan: Dictionary
var view := Vector2.ZERO
var t := 0.0
var frozen := -1.0
var wait := WAIT_FRAMES
var skip_at := -1.0
var skip_from := 1.0
var lang := "en"
var mat: ShaderMaterial
var name_tex: Texture2D
var item_bg := RID()
var item_name := RID()
var done := false
var recording := ""
var rec_frame := 0


static func wanted() -> bool:
	if App.args.has("nosplash"):
		return false
	if App.args.has("splash") or App.args.has("splash_record") or App.args.has("splash_live"):
		return true
	return not (App.args.has("capture") or App.args.has("selftest"))


func _ready() -> void:
	layer = 100
	data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	lang = SplashPlan.name_lang(String(App.args.get("lang", OS.get_locale_language())))
	name_tex = load("res://assets/splash/name_%s.png" % lang)
	mat = ShaderMaterial.new()
	mat.shader = preload("res://shaders/splash.gdshader")
	mat.set_shader_parameter("front_tex", preload("res://assets/splash/front.png"))
	mat.set_shader_parameter("full_tex", preload("res://assets/splash/full.png"))
	mat.set_shader_parameter("paper", Color(String(data["paper"])))
	mat.set_shader_parameter("smooth_edges", bool(App.settings["smooth_edges"]))
	var rs := RenderingServer
	item_bg = rs.canvas_item_create()
	rs.canvas_item_set_parent(item_bg, get_canvas())
	rs.canvas_item_set_material(item_bg, mat.get_rid())
	rs.canvas_item_set_draw_index(item_bg, 0)
	item_name = rs.canvas_item_create()
	rs.canvas_item_set_parent(item_name, get_canvas())
	rs.canvas_item_set_default_texture_filter(item_name, RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
	rs.canvas_item_set_draw_index(item_name, 1)
	if App.args.has("splash"):
		frozen = maxf(0.0, float(App.args["splash"]))
		t = frozen
		wait = 0
	recording = String(App.args.get("splash_record", ""))
	if recording != "":
		wait = 0
		DirAccess.make_dir_recursive_absolute(recording)
		RenderingServer.frame_post_draw.connect(_save_frame)
	get_tree().root.size_changed.connect(_layout)
	_layout()


## 첫 장면을 지금 그려 화면에 올린다. 장면을 만드는 _ready 안에서 부른다(엔진이 다 뜨기 전, 시스템 스플래시 뒤).
func draw_now() -> void:
	if recording == "" and frozen < 0.0:
		RenderingServer.force_draw(true, 0.0)


func _layout() -> void:
	view = get_viewport().get_visible_rect().size
	plan = SplashPlan.plan(view, App.density(), data)
	var rs := RenderingServer
	rs.canvas_item_clear(item_bg)
	rs.canvas_item_add_rect(item_bg, Rect2(Vector2.ZERO, view), Color.WHITE)
	mat.set_shader_parameter("view_size", view)
	mat.set_shader_parameter("center", plan["icon_center"])
	rs.canvas_item_clear(item_name)
	var size := name_tex.get_size() * int(plan["name_px"])
	var pos := Vector2(roundf((view.x - size.x) * 0.5), float(plan["name_top"]))
	rs.canvas_item_add_texture_rect(item_name, Rect2(pos, size), name_tex.get_rid())
	_apply()


func _apply() -> void:
	var s := SplashPlan.state(plan, t)
	mat.set_shader_parameter("scale", s["scale"])
	mat.set_shader_parameter("origin", s["origin"])
	mat.set_shader_parameter("radius", s["radius"])
	mat.set_shader_parameter("edge", s["edge"])
	mat.set_shader_parameter("back", s["back"])
	var f := SplashPlan.fade(t, skip_at, skip_from)
	mat.set_shader_parameter("fade", f)
	RenderingServer.canvas_item_set_modulate(item_name, Color(1.0, 1.0, 1.0, float(s["name"]) * f))


func _process(delta: float) -> void:
	if done:
		return
	if frozen >= 0.0:
		return
	if recording != "":
		t = rec_frame / RECORD_FPS
		_apply()
		return
	if wait > 0:
		wait -= 1
		return
	t += minf(delta, 1.0 / 30.0)   # 느린 프레임에서도 건너뛰지 않고 조금 느려질 뿐
	_apply()
	if SplashPlan.fade(t, skip_at, skip_from) <= 0.0:
		_finish()


## 누르면 지금 모습에서 바로 사라진다.
func skip() -> void:
	if done or frozen >= 0.0 or recording != "" or skip_at >= 0.0:
		return
	skip_from = SplashPlan.fade(t, skip_at, skip_from)
	skip_at = t
	wait = 0


func _input(event: InputEvent) -> void:
	if done:
		return
	var pointer := event is InputEventMouseButton or event is InputEventScreenTouch \
			or event is InputEventMouseMotion or event is InputEventScreenDrag
	if (event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventKey) and event.is_pressed():
		skip()
	if pointer:
		get_viewport().set_input_as_handled()   # 로딩 화면 밑의 게임(가방 밀기 등)에 손가락이 가지 않게


func _save_frame() -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/f%03d.png" % [recording, rec_frame])
	rec_frame += 1
	if rec_frame / RECORD_FPS > SplashPlan.FADE_END + 0.1:
		RenderingServer.frame_post_draw.disconnect(_save_frame)
		App.quit()


func _finish() -> void:
	done = true
	finished.emit()
	queue_free()


func _exit_tree() -> void:
	for rid in [item_bg, item_name]:
		if rid.is_valid():
			RenderingServer.free_rid(rid)
	item_bg = RID()
	item_name = RID()
