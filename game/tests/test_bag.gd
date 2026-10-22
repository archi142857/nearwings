extends "res://tests/test_case.gd"
## 가방 메뉴 배치(BagLayout): 시안 화면에서는 시안과 같고, 다른 화면에서도 가방이 화면 아래 반쯤에 들어가며
## 도구와 이름표가 안감 안에 겹치지 않게 놓이는지. 가방 그림을 늘이고 줄여도 무늬가 끊기지 않는지.

const SCENES := {"portrait": Vector2(240, 480), "square": Vector2(480, 480), "landscape": Vector2(480, 300)}
# 화면 화소 (perch_check.py와 같은 기기들)
const SCREENS := [
	Vector2(1080, 2400), Vector2(1080, 2340), Vector2(1080, 1920), Vector2(1179, 2556), Vector2(1080, 2640),
	Vector2(904, 2316), Vector2(1812, 2176), Vector2(2160, 2400), Vector2(2400, 2160), Vector2(2208, 1840),
	Vector2(1080, 1150), Vector2(1280, 1600), Vector2(1600, 2560), Vector2(1600, 2400), Vector2(1536, 2048),
	Vector2(2560, 1600), Vector2(2048, 1536), Vector2(1920, 1080),
]


func _data() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://assets/bag/bag.json"))


func _view(px: Vector2) -> Vector2:
	var s := Layout.choose_set(px, SCENES)
	return Layout.window_cells(px, Layout.cover_px(px, SCENES[s]))


func test_design_phone_matches_mockup() -> void:
	var d := _data()
	var lay := BagLayout.compute(Vector2(216, 480), d)
	eq(lay["row"], false, "폰은 시안 배치")
	near(lay["s"], 1.0, 1e-6, "줄이지 않는다")
	eq(lay["cols"], 0, "옆으로 늘이지 않는다")
	eq(lay["extra"], 0, "아래로 덧붙이지 않는다")
	eq(lay["size"], Vector2(206, 248), "가방 크기")
	check(lay["open_pos"].is_equal_approx(Vector2(5, 232)), "열린 가방 자리 = 시안 (25, 1160)화소: %s" % str(lay["open_pos"]))
	near(lay["closed_pos"].y, 464.0, 1e-6, "닫힌 가방은 윗단 16칸(80화소)만 보인다")
	check(lay["arrows_pos"].is_equal_approx(Vector2(102.8, 452)), "화살표 = 디자인 원본 (514, 2260)화소: %s" % str(lay["arrows_pos"]))
	var dogam: Rect2 = lay["items"][0]["art"]
	check(dogam.position.is_equal_approx(Vector2((156.0 - 25.0) / 5.0, (1504.0 - 1160.0) / 5.0)), "도감 자리 = 키트: %s" % str(dogam))


func test_every_screen_fits() -> void:
	var d := _data()
	for px in SCREENS:
		var view := _view(px)
		var lay := BagLayout.compute(view, d)
		var s: float = lay["s"]
		var size: Vector2 = lay["size"]
		var pos: Vector2 = lay["open_pos"]
		var name := "%dx%d" % [int(px.x), int(px.y)]
		check(s > 0.6 and s <= 1.0, "%s: 가방 배율 %.2f" % [name, s])
		check(pos.x >= BagLayout.SIDE - 0.01 and pos.x + size.x * s <= view.x - BagLayout.SIDE + 0.01, "%s: 가방이 화면 옆에 들어간다" % name)
		check(size.x * s >= view.x - 2.0 * BagLayout.SIDE - 16.0 * s - 0.01 or not lay["row"] and s < 1.0, "%s: 가방이 화면 폭을 거의 채운다" % name)
		var top_share := pos.y / view.y
		check(top_share > 0.4 and top_share < 0.6, "%s: 열린 가방 윗단이 화면 가운데쯤 (%.2f)" % [name, top_share])
		check(pos.y + size.y * s >= view.y - 0.01, "%s: 가방이 화면 아래 끝까지 닿는다" % name)
		_check_items(d, lay, name)


## 도구 그림과 이름표가 안감 안에 있고 서로 겹치지 않는다.
func _check_items(d: Dictionary, lay: Dictionary, name: String) -> void:
	var lining: Dictionary = d["lining"]
	var added_rows := 0
	for r in lay["rows"]:
		added_rows += int(r) * int(d["stretch"]["row_period"])
	var left := 0.0
	for v in lining["left"]:
		left = maxf(left, float(v))
	var right_min := INF
	for v in lining["right"]:
		right_min = minf(right_min, float(v))
	var inner := Rect2(left, float(lining["top"]), right_min + float(lay["size"].x) - float(d["bag"]["size"][0]) - left,
		float(lining["bottom"]) + added_rows - float(lining["top"]))
	var rects := []
	for it in lay["items"]:
		for key in ["art", "tag"]:
			var r: Rect2 = it[key]
			check(inner.grow(0.01).encloses(r), "%s: %s %s가 안감 안 (%s, 안감 %s)" % [name, it["id"], key, str(r), str(inner)])
		rects.append((it["art"] as Rect2).merge(it["tag"]))
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			check(not (rects[i] as Rect2).grow(-0.5).intersects(rects[j]), "%s: 도구 %d와 %d가 겹친다" % [name, i, j])


func test_index_map_keeps_pattern() -> void:
	var d := _data()
	var st: Dictionary = d["stretch"]
	var img := (load("res://assets/bag/bag.png") as Texture2D).get_image()
	var same := BagLayout.index_map(img.get_width(), 8, st["col_runs"], [0, 0])
	eq(same.size(), img.get_width(), "그대로면 칸 수가 같다")
	for plan in [[3, 3], [1, 0], [0, 2]]:
		var map := BagLayout.index_map(img.get_width(), 8, st["col_runs"], plan)
		eq(map.size(), img.get_width() + 8 * (plan[0] + plan[1]), "8칸 묶음을 더한 만큼 넓어진다 %s" % str(plan))
		_continuous(img, map, true, "칸 %s" % str(plan))
	for plan in [[-3, -3, -3], [2, 0, -1], [0, 4, 0]]:
		var map := BagLayout.index_map(img.get_height(), 12, st["row_runs"], plan)
		eq(map.size(), img.get_height() + 12 * (plan[0] + plan[1] + plan[2]), "12줄 묶음 %s" % str(plan))
		_continuous(img, map, false, "줄 %s" % str(plan))


## 새 그림에서 이웃한 두 줄(칸)이 원본에서도 이웃한 줄과 같은 내용이다 (늘이거나 줄인 곳에 이음매가 없다).
func _continuous(img: Image, map: PackedInt32Array, cols: bool, what: String) -> void:
	var n := img.get_width() if cols else img.get_height()
	var bad := 0
	for i in map.size() - 1:
		var a := map[i] + 1
		var b := map[i + 1]
		if a == b or a >= n:
			continue
		var m := img.get_height() if cols else img.get_width()
		for t in m:
			var ca := img.get_pixel(a, t) if cols else img.get_pixel(t, a)
			var cb := img.get_pixel(b, t) if cols else img.get_pixel(t, b)
			if not ca.is_equal_approx(cb):
				bad += 1
				break
	eq(bad, 0, "%s: 이음매" % what)


func test_spread_respects_limits() -> void:
	var runs := [[49, 81], [94, 126], [139, 171]]
	eq(BagLayout.spread(0, runs, 12), [0, 0, 0], "0")
	eq(BagLayout.spread(4, runs, 12), [1, 2, 1], "더하기는 가운데부터 고루")
	var minus := BagLayout.spread(-20, runs, 12)
	eq(minus, [-3, -3, -3], "빼기는 구간마다 뺄 수 있는 만큼까지")


## 움직임 곡선이 디자인 배치값(art/bag/design_layout.json 'motion')대로인지.
func test_motion_curves_follow_design_values() -> void:
	near(BagLayout.bag_progress(0.0), 0.0, 1e-6, "가방은 처음에 그대로")
	near(BagLayout.bag_progress(0.06), 0.0, 1e-6, "밀기 6%까지는 따라오지 않는다")
	near(BagLayout.bag_progress(1.0), 1.0, 1e-6, "끝에서 열린 자리")
	near(BagLayout.bag_progress(0.5), 0.45 * (0.44 / 0.94) + 0.55 * BagLayout.ease_in_out_cubic(0.44 / 0.94), 1e-6, "가운데는 배치값 공식")
	var prev := 0.0
	for i in 101:
		var v := BagLayout.bag_progress(i / 100.0)
		check(v >= prev - 1e-6 and v <= 1.0 + 1e-6, "가방 자리는 줄지 않고 넘치지 않는다 (s=%.2f, %.4f)" % [i / 100.0, v])
		prev = v
	near(BagLayout.focus(0.25), 0.0, 1e-6, "흐림은 밀기 25%에서 시작")
	near(BagLayout.focus(0.55), 0.5, 1e-6, "55%에서 절반")
	near(BagLayout.focus(0.85), 1.0, 1e-6, "85%에서 다 흐리다")
