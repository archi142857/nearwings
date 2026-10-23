class_name SplashPlan
extends RefCounted
## 로딩 화면의 자리와 시간표. 상태가 없는 함수만 둔다 (단위 시험 대상).
##
## 첫 장면은 안드로이드 12 이상의 시스템 스플래시와 같다. 스플래시 그림(적응형 아이콘 앞 레이어와 같은 192칸)은
## 288dp로 그려지고 가운데 지름 192dp 원만 보이므로, 아이콘 B 창(128칸)이 화면 가운데에 칸당 1.5dp로 보인다.
## 원이 바깥쪽으로만 부드럽게 퍼지며 까치 전체가 드러나고, 그동안 화면이 물러나며(칸당 1.5dp → 정수 배율 k)
## 디자인 마지막 화면 자리로 간다. 뒤 날개는 조금 늦게 들어오고, 이름이 뜬 뒤 게임으로 넘어간다
## (결정 기록 작업 기준 '로딩 순서', 디자인 캔버스 '앱 아이콘 · 로딩 화면').
## 사용자 결정(2026-10-23): 로딩 화면은 길게 잡지 않는다. 디자인 시안의 1.7초 + 0.5초를 0.85초로 줄였고, 누르면 바로 넘어간다.
## 칸 좌표는 캔버스(assets/splash/full.png) 기준, data는 assets/splash/splash.json.

const MOVE_END := 0.50       # 물러나며 자리 옮기기 (ease-in-out cubic). 시안 1.48초
const REVEAL_END := 0.30     # 원이 까치 끝까지 퍼짐 (일정한 빠르기). 시안 0.74초
const EDGE_IN := 0.06        # 처음 또렷한 가장자리가 부드러워지는 시간
const BACK_START := 0.06     # 뒤 날개 (시안 0.16~0.98초)
const BACK_END := 0.38
const NAME_START := 0.42     # 이름 (시안 0.5초)
const NAME_END := 0.58
const FADE_START := 0.70     # 게임으로 넘어가기
const FADE_END := 0.85
const SKIP_FADE := 0.15      # 눌러서 넘길 때 사라지는 시간
const EDGE_SCREEN := 0.2     # 부드러운 띠 폭: 화면 높이의 약 1/5
const WIDTH_SHARE := 0.72    # 마지막 배율: 까치가 화면 폭의 70%쯤 (1080 폭 폰에서 칸당 3화소)
const HEIGHT_SHARE := 0.86   # 까치와 이름이 화면 높이 안에 들게


static func ease_in_out_cubic(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return 4.0 * u * u * u if u < 0.5 else 1.0 - pow(-2.0 * u + 2.0, 3.0) * 0.5


## 까치와 이름이 차지하는 범위 (화면 가운데에서 잰 칸, 칸 배율 1일 때): x = 왼쪽, y = 위, z = 오른쪽, w = 아래.
static func group_extent(data: Dictionary) -> Vector4:
	var cfc: Array = data["canvas_from_center"]
	var bb: Array = data["magpie_bbox"]
	var name_h := 0.0
	for lang in data["names"]:
		name_h = maxf(name_h, float(data["names"][lang][1]) * float(data["name_cell_ratio"]))
	return Vector4(float(cfc[0]) + float(bb[0]), float(cfc[1]) + float(bb[1]),
			float(cfc[0]) + float(bb[2]), float(data["name_top_from_center"]) + name_h)


## 마지막 화면의 칸 배율(정수). 1080 폭 폰에서 3, 더 큰 화면은 정수만큼 올린다.
static func final_cell_px(view: Vector2, data: Dictionary) -> int:
	var g := group_extent(data)
	var by_width := floori(WIDTH_SHARE * view.x / (g.z - g.x))
	var by_height := floori(HEIGHT_SHARE * view.y * 0.5 / maxf(-g.y, g.w))
	return maxi(1, mini(by_width, by_height))


## 화면과 기기 배율(1dp = density 화소)에 맞춘 자리.
static func plan(view: Vector2, density: float, data: Dictionary) -> Dictionary:
	var k := final_cell_px(view, data)
	var center := view * 0.5
	var ic := Vector2(data["icon_center"][0], data["icon_center"][1])
	var cfc := Vector2(data["canvas_from_center"][0], data["canvas_from_center"][1])
	var origin_final := (center + cfc * k).round()
	var s0 := float(data["first_circle_dp"]) / float(data["icon_cells"]) * density
	var bb: Array = data["magpie_bbox"]
	var r_end := 0.0
	for x in [bb[0], bb[2]]:
		for y in [bb[1], bb[3]]:
			r_end = maxf(r_end, (Vector2(x, y) - ic).length())
	var name_px := maxi(1, roundi(k * float(data["name_cell_ratio"])))
	return {
		"k": k,
		"s0": s0,
		"icon_center": ic,
		"p0": center,                                  # 첫 장면: 아이콘 가운데 = 화면 가운데 (시스템 스플래시)
		"p1": origin_final + ic * k,                   # 마지막 화면의 아이콘 가운데
		"origin_final": origin_final,
		"r0": float(data["icon_cells"]) * 0.5,         # 192dp 원 = 아이콘 창에 내접
		"r_end": ceilf(r_end) + 1.0,
		"edge_max": EDGE_SCREEN * view.y / s0,
		"name_px": name_px,
		"name_top": roundf(center.y + float(data["name_top_from_center"]) * k),
	}


## t초의 모습: 칸 배율, 캔버스 (0, 0)의 화면 자리, 드러난 원(칸), 뒤 날개·이름 알파.
static func state(p: Dictionary, t: float) -> Dictionary:
	var e := ease_in_out_cubic(t / MOVE_END)
	var s := lerpf(p["s0"], float(p["k"]), e)
	var pos: Vector2 = (p["p0"] as Vector2).lerp(p["p1"], e)
	var origin: Vector2 = p["origin_final"] if e >= 1.0 else pos - (p["icon_center"] as Vector2) * s
	return {
		"scale": float(p["k"]) if e >= 1.0 else s,
		"origin": origin,
		"radius": lerpf(p["r0"], p["r_end"], clampf(t / REVEAL_END, 0.0, 1.0)),
		"edge": float(p["edge_max"]) * smoothstep(0.0, EDGE_IN, t),
		"back": smoothstep(BACK_START, BACK_END, t),
		"name": smoothstep(NAME_START, NAME_END, t),
	}


## 로딩 화면 전체 알파. skip_at(누른 때, 없으면 음수)부터는 그때 알파에서 SKIP_FADE 동안 사라진다.
static func fade(t: float, skip_at := -1.0, skip_from := 1.0) -> float:
	var f := 1.0 - smoothstep(FADE_START, FADE_END, t)
	if skip_at >= 0.0:
		f = minf(f, skip_from * (1.0 - clampf((t - skip_at) / SKIP_FADE, 0.0, 1.0)))
	return f


## 이 언어로 띄울 이름: 기기 언어가 한국어면 새바라기, 그 밖은 NearWings (결정 기록 2026-10-19).
static func name_lang(locale_language: String) -> String:
	return "ko" if locale_language == "ko" else "en"
