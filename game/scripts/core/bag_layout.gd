class_name BagLayout
extends RefCounted
## 가방 메뉴 배치: 화면 크기(배경 칸)에 맞춰 가방을 얼마나 줄이고 늘일지, 도구를 어디에 둘지 정한다.
## 상태가 없는 함수만 둔다 (단위 시험 대상). 가방 그림·자리 자료는 assets/bag/bag.json (tools/bag_import.py).
##
## 시안은 1080×2400 폰(배경 칸 5화소, 화면 216×480칸)이다. 가방은 206×248칸이고 열리면 윗단이 위에서 232칸(1160화소),
## 닫혀 있을 때는 윗단 16칸(80화소)만 보인다. 이 화면에서는 시안과 칸까지 같게 놓는다.
##   - 세로로 긴 화면: 시안 배치 그대로. 화면이 낮거나 좁으면 가방과 도구를 함께 줄이고(s < 1),
##     넓으면 가방만 옆으로 늘인다(8칸 묶음, 무늬가 이어지는 곳에서).
##   - 넓은 화면(가로÷세로 0.75 이상: 폴더블 펼침, 태블릿 가로): 가방을 옆으로 늘이고 도구를 한 줄로 놓는다.
##     가방 높이는 화면의 절반쯤이 되게 안감 줄(12줄 묶음)을 더하거나 뺀다.
## 단위: '가방 칸' = 시안 5화소. 화면에서는 가방 한 칸 = 배경 s칸.

const ROW_ASPECT := 0.75                 # 화면 가로÷세로가 이 이상이면 도구를 한 줄로
const SIDE := 5.0                        # 가방 양옆에 보이는 바닥 (배경 칸)
const OPEN_TOP := 1160.0 / 2400.0        # 열렸을 때 가방 윗단 (화면 높이 비율)
const DESIGN_VIEW := Vector2(216.0, 480.0)
const DESIGN_PX := 5.0                   # 시안에서 가방 한 칸 (화소)
const TAG_GAP := 8.0 / DESIGN_PX         # 이름표는 그림 아래 8화소
const ROW_MARGIN := 14.0                 # 한 줄 배치: 도구 무리 위아래 안감 여백 (가방 칸)
const FRONT_ROWS := 42                   # 열린 가방에서 보이는 앞면 (라벨까지, 가방 칸)
const ARROW_GAP := 12.0                  # 닫힌 가방 윗단에서 화살표 윗변까지 (가방 칸, 시안 60화소)
# 움직임 (디자인 세션 배치값 art/bag/design_layout.json 'motion'). s = 밀기 정도 (0 = 공원, 1 = 가방 속)
const BAG_LAG := 0.06                    # 가방은 s가 이만큼 지나서야 따라오기 시작한다
const FOCUS_FROM := 0.25                 # 바닥이 흐려지기 시작하는 s
const FOCUS_TO := 0.85                   # 다 흐려지는 s


## 화면(배경 칸)에 맞춘 배치. 결과:
##   row: 한 줄 배치인지, s: 가방 한 칸 = 배경 몇 칸, cols: 양쪽 늘임 구간마다 더한 8칸 묶음 수,
##   rows: 안감 늘임 구간마다 더한(음수면 뺀) 12줄 묶음 수 [Array], extra: 아래에 덧붙인 줄 수,
##   size: 가방 크기(가방 칸), open_pos / closed_pos: 가방 왼쪽 위(화면, 배경 칸), arrows_pos, arrows_size(배경 칸),
##   items: [{id, art: Rect2, tag: Rect2}] 가방 왼쪽 위 기준(가방 칸)
static func compute(view: Vector2, d: Dictionary) -> Dictionary:
	var base := _vec(d["bag"]["size"])                     # 206×248
	var lining: Dictionary = d["lining"]
	var lining_rows := int(lining["bottom"]) - int(lining["top"]) + 1
	var row := view.x / maxf(view.y, 1.0) >= ROW_ASPECT
	var target := view.y * (1.0 - OPEN_TOP)               # 열린 가방이 차지할 높이 (배경 칸)
	var avail_w := maxf(view.x - 2.0 * SIDE, 1.0)
	var out := {"row": row}
	var s := 1.0
	var rows_add := [0, 0, 0]
	var vis_rows := 0.0
	if not row:
		var s_h := minf(1.0, view.y / DESIGN_VIEW.y)
		s = minf(s_h, minf(1.0, avail_w / base.x))
		vis_rows = target / s
	else:
		var group_h := _row_group_height(d)
		var need := float(lining["top"]) + group_h + 2.0 * ROW_MARGIN + FRONT_ROWS
		s = minf(1.0, target / need)
		vis_rows = target / s
		var want := vis_rows - float(lining["top"]) - FRONT_ROWS
		var r := int(round((want - lining_rows) / float(d["stretch"]["row_period"])))
		rows_add = spread(r, d["stretch"]["row_runs"], int(d["stretch"]["row_period"]))
	var cols := maxi(0, int(floor((avail_w / s - base.x) / (2.0 * float(d["stretch"]["col_period"])))))
	var h0 := base.y + _sum(rows_add) * float(d["stretch"]["row_period"])
	var extra := maxi(0, int(ceil(vis_rows - h0 - 0.001)))
	var size := Vector2(base.x + 2.0 * cols * float(d["stretch"]["col_period"]), h0 + extra)
	out["s"] = s
	out["cols"] = cols
	out["rows"] = rows_add
	out["extra"] = extra
	out["size"] = size
	out["open_pos"] = Vector2((view.x - size.x * s) * 0.5, view.y - target)
	var hint := float(d["hint_rows"])
	out["closed_pos"] = Vector2(out["open_pos"].x, view.y - hint * s)
	var ap: Dictionary = d["pieces"]["arrows"]
	var asz := _vec(ap["size"]) * float(ap["px_per_cell"]) / DESIGN_PX * s
	out["arrows_size"] = asz
	out["arrows_pos"] = Vector2((view.x - asz.x) * 0.5, out["closed_pos"].y - ARROW_GAP * s)
	out["items"] = _row_items(d, size, rows_add) if row else _design_items(d, cols)
	return out


## 시안 자리 그대로 (가방 왼쪽 위 기준, 가방 칸). 가방을 옆으로 늘인 만큼 가운데 쪽으로 민다.
static func _design_items(d: Dictionary, cols: int) -> Array:
	var bag_tl := _vec(d["bag"]["tl_px"])
	var shift := Vector2(cols * float(d["stretch"]["col_period"]), 0.0)
	var out := []
	for t in d["tools"]:
		out.append({"id": t["id"], "art": _piece_rect(d, t["art"], bag_tl, shift), "tag": _piece_rect(d, t["tag"], bag_tl, shift)})
	return out


static func _piece_rect(d: Dictionary, key: String, bag_tl: Vector2, shift: Vector2) -> Rect2:
	var p: Dictionary = d["pieces"][key]
	var k := float(p["px_per_cell"]) / DESIGN_PX
	return Rect2((_vec(p["tl_px"]) - bag_tl) / DESIGN_PX + shift, _vec(p["size"]) * k)


static func _piece_size(d: Dictionary, key: String) -> Vector2:
	var p: Dictionary = d["pieces"][key]
	return _vec(p["size"]) * float(p["px_per_cell"]) / DESIGN_PX


## 한 줄 배치의 도구 무리 높이: 가장 큰 그림 + 간격 + 가장 큰 이름표.
static func _row_group_height(d: Dictionary) -> float:
	var art_h := 0.0
	var tag_h := 0.0
	for t in d["tools"]:
		art_h = maxf(art_h, _piece_size(d, t["art"]).y)
		tag_h = maxf(tag_h, _piece_size(d, t["tag"]).y)
	return art_h + TAG_GAP + tag_h


## 한 줄 배치: 도감·쌍안경·카메라를 안감 안에 같은 간격으로, 그림 아랫변을 맞춰 놓는다.
static func _row_items(d: Dictionary, size: Vector2, rows_add: Array) -> Array:
	var lining: Dictionary = d["lining"]
	var top := float(lining["top"])
	var bottom := float(lining["bottom"]) + _sum(rows_add) * float(d["stretch"]["row_period"])
	var left := 0.0
	for v in lining["left"]:
		left = maxf(left, float(v))
	var right := size.x - 1.0 - (float(d["bag"]["size"][0]) - 1.0 - _min(lining["right"]))
	var inner_l := left + 2.0
	var inner_r := right - 2.0
	var widths := []
	var total := 0.0
	var art_h := 0.0
	for t in d["tools"]:
		var w := _piece_size(d, t["art"]).x
		widths.append(w)
		total += w
		art_h = maxf(art_h, _piece_size(d, t["art"]).y)
	var gap := maxf(0.0, (inner_r - inner_l - total) / float(widths.size() + 1))
	var group_h := _row_group_height(d)
	var baseline := top + ((bottom - top + 1.0) - group_h) * 0.5 + art_h
	var x := inner_l + gap
	var out := []
	for i in d["tools"].size():
		var t: Dictionary = d["tools"][i]
		var asz := _piece_size(d, t["art"])
		var tsz := _piece_size(d, t["tag"])
		var art := Rect2(Vector2(x, baseline - asz.y), asz)
		var tag := Rect2(Vector2(art.get_center().x - tsz.x * 0.5, baseline + TAG_GAP), tsz)
		out.append({"id": t["id"], "art": art, "tag": tag})
		x += asz.x + gap
	return out


## s에 따른 가방 자리 (0 = 닫힘, 1 = 열림, 배치값 bag_progress): 늦게 출발해 빨라졌다가 끝에서 살짝 더 밀려 자리 잡는다.
static func bag_progress(s: float) -> float:
	var x := clampf((s - BAG_LAG) / (1.0 - BAG_LAG), 0.0, 1.0)
	return 0.45 * x + 0.55 * ease_in_out_cubic(x) + 0.03 * sin(PI * clampf((x - 0.7) / 0.3, 0.0, 1.0))


## s에 따른 흐림 정도 a (배치값 focus_pull): 바닥 흐림, 채도 빼기, 어둡게 하기, 가방 그림자 세기에 쓴다.
static func focus(s: float) -> float:
	return smoothstep(FOCUS_FROM, FOCUS_TO, s)


static func ease_in_out_cubic(u: float) -> float:
	return 4.0 * u * u * u if u < 0.5 else 1.0 - pow(-2.0 * u + 2.0, 3.0) * 0.5


## n개 묶음을 늘임 구간들에 고루 나눈다. 빼는 묶음(음수)은 구간마다 뺄 수 있는 만큼까지만.
static func spread(n: int, runs: Array, period: int) -> Array:
	var out := []
	for i in runs.size():
		out.append(0)
	if runs.is_empty() or n == 0:
		return out
	var caps := []
	for r in runs:
		caps.append(int(floor((float(r[1]) - float(r[0])) / period)) + 1)
	var left := absi(n)
	var sgn := 1 if n > 0 else -1
	var i := 0
	var stuck := 0
	while left > 0 and stuck < runs.size():
		var j := (i + runs.size() / 2) % runs.size()   # 가운데 구간부터 돌아가며
		if sgn > 0 or absi(out[j]) < caps[j]:
			out[j] += sgn
			left -= 1
			stuck = 0
		else:
			stuck += 1
		i += 1
	return out


## 늘이거나 줄인 그림에서 줄(또는 칸)마다 원본의 몇 번째를 쓸지. runs: 주기적인 구간 [[처음, 끝], ...]
## (그 안의 i는 i번째와 i+period번째가 같다), add: 구간마다 더할(음수면 뺄) 묶음 수. 끝에 extra만큼 마지막 줄을 되풀이한다.
static func index_map(n: int, period: int, runs: Array, add: Array, extra := 0) -> PackedInt32Array:
	var plan := {}
	for j in runs.size():
		plan[int(runs[j][0])] = int(add[j])
	var out := PackedInt32Array()
	var i := 0
	while i < n:
		var m: int = plan.get(i, 0)
		plan.erase(i)
		if m > 0:
			for rep in m:
				for t in period:
					out.append(i + t)
		elif m < 0:
			i += period * -m
			continue
		out.append(i)
		i += 1
	for e in extra:
		out.append(n - 1)
	return out


## 원본 가방 그림을 배치대로 늘이거나 줄인 새 그림.
static func build_image(src: Image, layout: Dictionary, d: Dictionary) -> Image:
	var st: Dictionary = d["stretch"]
	var cols := index_map(src.get_width(), int(st["col_period"]), st["col_runs"], [layout["cols"], layout["cols"]])
	var rows := index_map(src.get_height(), int(st["row_period"]), st["row_runs"], layout["rows"], int(layout["extra"]))
	var dst := Image.create_empty(cols.size(), rows.size(), false, src.get_format())
	for ry in _segments(rows):
		for cx in _segments(cols):
			dst.blit_rect(src, Rect2i(cx[0], ry[0], cx[2], ry[2]), Vector2i(cx[1], ry[1]))
	return dst


## 이어지는 구간들 [원본 시작, 새 그림 시작, 길이].
static func _segments(map: PackedInt32Array) -> Array:
	var out := []
	var i := 0
	while i < map.size():
		var j := i + 1
		while j < map.size() and map[j] == map[j - 1] + 1:
			j += 1
		out.append([map[i], i, j - i])
		i = j
	return out


static func _vec(a: Variant) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


static func _sum(a: Array) -> int:
	var t := 0
	for v in a:
		t += int(v)
	return t


static func _min(a: Array) -> float:
	var m := INF
	for v in a:
		m = minf(m, float(v))
	return m
