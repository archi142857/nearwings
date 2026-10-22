extends Node
## 앱 전체 상태 (자동 로드 'App'): 실행 인자, 기기 정보, 시험용 설정, 방향 고정.
##
## 실행 인자는 `--` 뒤에 붙인다. 예: godot --path game -- --density=2.625 --capture=shot.png
##   --capture=<png>  화면을 찍고 끝낸다 (--frames=<n> 프레임 뒤, 기본 40)
##   --density=<x>    1dp가 몇 화소인지 (데스크톱에서 폰 흉내)
##   --seed=<n>       새 움직임을 매번 같게
##   --prewarm        새를 처음부터 앉혀 둔다
##   --set=<portrait|square|landscape>  배경 벌을 정해 쓴다 (기본은 화면 비율에 가장 가까운 벌)
##   --bg_ratio=<r> --evening=<0~1> --smooth=<0|1> --snap=<0|1> --bird_count=<n> --ui=<0|1>

signal settings_changed

var args := {}
var rng := RandomNumberGenerator.new()
var settings := {
	"bg_ratio": 1.25,       # 배경 칸이 새 칸의 몇 배인지 (결정 기록: 1.25)
	"smooth_edges": true,   # 정수가 아닌 배율에서 칸 경계만 1화소 안에서 섞기
	"snap_motion": false,   # 새와 화면을 칸 단위로 끊어 움직이기 (비교용)
	"evening": 0.0,         # 0 = 낮, 1 = 저녁 (임시 저녁 색표)
	"bird_count": 5,
	"show_ui": true,
}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if args.has("seed"):
		rng.seed = int(args["seed"])
	else:
		rng.randomize()
	if args.has("bg_ratio"):
		settings["bg_ratio"] = float(args["bg_ratio"])
	if args.has("evening"):
		settings["evening"] = float(args["evening"])
	if args.has("smooth"):
		settings["smooth_edges"] = args["smooth"] != "0"
	if args.has("snap"):
		settings["snap_motion"] = args["snap"] != "0"
	if args.has("bird_count"):
		settings["bird_count"] = int(args["bird_count"])
	if args.has("ui"):
		settings["show_ui"] = args["ui"] != "0"
	get_tree().root.size_changed.connect(apply_orientation_policy)
	apply_orientation_policy()


func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	settings_changed.emit()


## 1dp가 몇 화소인지.
func density() -> float:
	if args.has("density"):
		return float(args["density"])
	if OS.has_feature("android"):
		var dpi := DisplayServer.screen_get_dpi()   # 안드로이드는 densityDpi (160 = 1dp당 1화소)
		if dpi > 0:
			return clampf(dpi / 160.0, 1.0, 6.0)
	if OS.has_feature("mobile"):
		var s := DisplayServer.screen_get_scale()
		if s > 1.0:
			return s
		return maxf(1.0, DisplayServer.screen_get_dpi() / 160.0)
	return 1.0


## 폰 크기 화면은 세로로 고정하고, 큰 화면(폴더블 펼침, 태블릿)은 모든 방향을 허용한다.
## 매니페스트로 고정하면 게임으로 분류한 앱은 펼친 폴더블에서도 세로로 묶이므로 실행 중에 정한다.
func apply_orientation_policy() -> void:
	if not OS.has_feature("mobile"):
		return
	var screen := Vector2(DisplayServer.screen_get_size())
	var want := DisplayServer.SCREEN_PORTRAIT if Layout.is_phone_sized(screen, density()) else DisplayServer.SCREEN_SENSOR
	if DisplayServer.screen_get_orientation() != want:
		DisplayServer.screen_set_orientation(want)


func is_phone_now() -> bool:
	var size := Vector2(DisplayServer.screen_get_size()) if OS.has_feature("mobile") else Vector2(get_tree().root.size)
	return Layout.is_phone_sized(size, density())
