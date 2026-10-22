extends "res://tests/test_case.gd"
## 배경 벌 고르기·배율·방향 규칙 (03_개발 계획 '화면 배율', '좌표와 방향').

const SIZES := {"portrait": Vector2(240, 480), "square": Vector2(480, 480), "landscape": Vector2(480, 300)}


func test_choose_set_by_ratio() -> void:
	# [화면, 골라야 할 벌]
	var table := [
		[Vector2(1080, 2400), "portrait"],   # 폰 20:9
		[Vector2(1080, 2640), "portrait"],   # 플립 22:9
		[Vector2(904, 2316), "portrait"],    # 폴더블 바깥 화면
		[Vector2(1179, 2556), "portrait"],   # 아이폰
		[Vector2(1600, 2560), "portrait"],   # 태블릿 세로 16:10 (0.625)
		[Vector2(2160, 2400), "square"],     # 폴더블 펼침 세로
		[Vector2(2400, 2160), "square"],     # 폴더블 펼침 가로
		[Vector2(1080, 1150), "square"],     # 창 나누기
		[Vector2(1536, 2048), "square"],     # 태블릿 세로 4:3 (0.75)
		[Vector2(2208, 1840), "square"],     # 펼친 폴더블 1.2
		[Vector2(2560, 1600), "landscape"],  # 태블릿 가로 16:10
		[Vector2(2048, 1536), "landscape"],  # 태블릿 가로 4:3 (1.33)
		[Vector2(1920, 1080), "landscape"],  # 16:9 가로
	]
	for row in table:
		eq(Layout.choose_set(row[0], SIZES), row[1], "%s" % str(row[0]))


func test_boundaries_are_geometric_means() -> void:
	# 0.5와 1.0의 가운데는 √0.5 ≈ 0.707, 1.0과 1.6의 가운데는 √1.6 ≈ 1.265
	eq(Layout.choose_set(Vector2(700, 1000), SIZES), "portrait", "0.70")
	eq(Layout.choose_set(Vector2(715, 1000), SIZES), "square", "0.715")
	eq(Layout.choose_set(Vector2(1260, 1000), SIZES), "square", "1.26")
	eq(Layout.choose_set(Vector2(1270, 1000), SIZES), "landscape", "1.27")


func test_missing_sets_fall_back() -> void:
	eq(Layout.choose_set(Vector2(2560, 1600), {"square": Vector2(480, 480)}), "square", "한 벌만 있으면 그것")


func test_cover_fills_screen() -> void:
	near(Layout.cover_px(Vector2(1080, 2400), SIZES["portrait"]), 5.0, 1e-6, "기준 폰은 한 칸 5화소")
	var w := Layout.window_cells(Vector2(1080, 2400), 5.0)
	near(w.x, 216.0, 1e-4, "폰에서 보이는 너비 (세로형 240칸 중)")
	near(w.y, 480.0, 1e-4, "폰에서 보이는 높이")
	var tab := Layout.cover_px(Vector2(1600, 2560), SIZES["portrait"])
	near(tab, 1600.0 / 240.0, 1e-6, "태블릿 세로는 너비를 채운다")
	near(Layout.window_cells(Vector2(1600, 2560), tab).y, 384.0, 1e-3, "태블릿 세로에서 보이는 높이")
	near(Layout.cover_px(Vector2(2160, 2400), SIZES["square"]), 5.0, 1e-6, "폴더블 펼침 세로도 5화소")
	near(Layout.cover_px(Vector2(2560, 1600), SIZES["landscape"]), 2560.0 / 480.0, 1e-6, "태블릿 가로 16:10은 딱 맞는다")
	for s in SIZES:
		for v in [Vector2(1080, 2400), Vector2(2160, 2400), Vector2(2560, 1600), Vector2(1080, 1150)]:
			var c := Layout.window_cells(v, Layout.cover_px(v, SIZES[s]))
			check(c.x <= SIZES[s].x + 1e-3 and c.y <= SIZES[s].y + 1e-3, "%s가 %s 화면을 꽉 채운다" % [s, str(v)])


func test_phone_detection() -> void:
	check(Layout.is_phone_sized(Vector2(1080, 2400), 2.625), "폰은 세로 고정")
	check(Layout.is_phone_sized(Vector2(1080, 2520), 2.625), "폴더블 바깥 화면은 폰")
	check(not Layout.is_phone_sized(Vector2(2160, 2400), 2.625), "폴더블 펼침은 모든 방향")
	check(not Layout.is_phone_sized(Vector2(1600, 2560), 2.0), "태블릿은 모든 방향")


func test_snapped_center_moves_by_pixels() -> void:
	var c := Layout.snapped_center(Vector2(108.13, 240.0), Vector2(216, 480), 0.2)
	var k := (c.x - 108.0) / 0.2
	near(k, round(k), 1e-3, "왼쪽 위가 0.2칸 단위")
	near(c.x, 108.2, 1e-3, "가장 가까운 0.2칸으로")


func test_size_rule_matches_design_table() -> void:
	# 결정 기록 크기 규칙과 디자인 캔버스 Pg_Lineup의 칸 수: [몸길이(cm), 칸 수]
	var table := [[14.0, 18], [12.5, 17], [46.0, 41], [58.0, 48], [57.0, 47], [33.0, 32], [28.0, 29], [86.0, 62]]
	for row in table:
		near(Layout.size_rule_cells(row[0]), float(row[1]), 1.0, "%scm" % str(row[0]))
