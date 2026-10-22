class_name Layout
extends RefCounted
## 화면 배율과 배경 벌 고르기. 상태가 없는 함수만 둔다 (단위 시험 대상).
##
## 배경은 서식지마다 세로형·정사각형·가로형 세 벌이 있다(결정 기록 2026-10-22).
## 화면 비율(가로÷세로)에 가장 가까운 벌을 골라 화면에 꽉 차게 그리고, 비율이 조금 다른 만큼 가장자리를 똑같이 자른다.
## 단위: 장면 좌표는 그 벌의 배경 칸.

const SET_NAMES := ["portrait", "square", "landscape"]
const SET_LABELS := {"portrait": "세로형", "square": "정사각형", "landscape": "가로형"}
const PHONE_MAX_SHORT_DP := 600.0


## 화면 비율에 가장 가까운 벌. sizes = {벌 이름: 장면 크기(칸)}. 비율은 로그로 견준다(0.5와 1.0의 가운데는 0.71).
static func choose_set(view_px: Vector2, sizes: Dictionary) -> String:
	var a := view_px.x / maxf(view_px.y, 1.0)
	var best := ""
	var best_d := INF
	for name in SET_NAMES:
		if not sizes.has(name):
			continue
		var s: Vector2 = sizes[name]
		var d := absf(log(a / (s.x / s.y)))
		if d < best_d:
			best_d = d
			best = name
	return best


## 배경 한 칸이 화면 몇 화소인지: 장면이 화면을 꽉 채우는 가장 작은 배율.
## 세로형 240×480이 1080×2400 폰에서 5화소(가로는 가운데 216칸만 보임).
static func cover_px(view_px: Vector2, scene: Vector2) -> float:
	return maxf(view_px.x / scene.x, view_px.y / scene.y)


## 화면에 보이는 장면 크기(배경 칸).
static func window_cells(view_px: Vector2, cell_px: float) -> Vector2:
	return view_px / cell_px


## 짧은 변이 600dp 미만이면 폰 크기로 보고 세로로 고정한다. 그 이상(폴더블 펼침, 태블릿)은 모든 방향.
static func is_phone_sized(size_px: Vector2, density: float) -> bool:
	return minf(size_px.x, size_px.y) / maxf(density, 0.01) < PHONE_MAX_SHORT_DP


## 크기 규칙(결정 기록): 칸 수 = 2.98 × 몸길이(cm)^0.68.
static func size_rule_cells(length_cm: float) -> float:
	return 2.98 * pow(length_cm, 0.68)


## 왼쪽 위 모서리를 step 단위로 맞춘 화면 가운데. 장면 칸 경계가 화면 화소에 맞게 떨어지게 한다.
static func snapped_center(center: Vector2, view_cells: Vector2, step: float) -> Vector2:
	var top_left := (center - view_cells * 0.5).snapped(Vector2(step, step))
	return top_left + view_cells * 0.5
