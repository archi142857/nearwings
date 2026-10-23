extends "res://tests/test_case.gd"
## 로딩 화면의 자리와 시간표 (SplashPlan, 결정 기록 작업 기준 '로딩 순서', 2026-10-23 '길게 잡지 않는다').

const DEVICES := [
	# [화면, 1dp 화소 수, 마지막 칸 배율]
	[Vector2(1080, 2400), 2.625, 3],   # 기준 폰: 디자인 마지막 화면과 같다
	[Vector2(1080, 2340), 2.625, 3],
	[Vector2(1440, 3120), 3.5, 4],     # QHD 폰은 정수만큼 올린다
	[Vector2(720, 1600), 1.75, 2],
	[Vector2(1179, 2556), 3.0, 3],
	[Vector2(1080, 2640), 2.625, 3],
	[Vector2(904, 2316), 2.625, 2],    # 폴더블 바깥 화면
	[Vector2(2160, 2400), 2.625, 5],   # 폴더블 펼침 세로
	[Vector2(2400, 2160), 2.625, 4],   # 폴더블 펼침 가로
	[Vector2(1600, 2560), 2.0, 4],     # 태블릿 세로
	[Vector2(2560, 1600), 2.0, 3],     # 태블릿 가로
	[Vector2(1080, 1150), 2.625, 2],   # 창 나누기
]


func data() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://assets/splash/splash.json"))


func test_short() -> void:
	check(SplashPlan.FADE_END < 1.0, "로딩 화면은 1초 안에 끝난다 (사용자, 10-23)")
	check(SplashPlan.SKIP_FADE <= 0.2, "누르면 바로 넘어간다")
	check(SplashPlan.MOVE_END <= SplashPlan.FADE_START and SplashPlan.NAME_END <= SplashPlan.FADE_START, "이름까지 뜬 뒤 넘어간다")


func test_reference_phone_matches_design() -> void:
	var p := SplashPlan.plan(Vector2(1080, 2400), 2.625, data())
	eq(p["k"], 3, "1080 폭 폰은 칸당 3화소")
	eq(p["origin_final"], Vector2(154, 482), "디자인 마지막 화면 자리")
	eq(p["name_top"], 1640.0, "이름 위")
	eq(p["name_px"], 8, "이름 글자 칸 8배")
	near(p["s0"], 3.9375, 1e-6, "첫 장면 칸당 화소 = 192dp ÷ 128칸")


func test_first_frame_is_system_splash() -> void:
	for row in DEVICES:
		var p := SplashPlan.plan(row[0], row[1], data())
		var s := SplashPlan.state(p, 0.0)
		near(s["scale"], 1.5 * row[1], 1e-6, "%s 칸당 1.5dp" % str(row[0]))
		var ic: Vector2 = p["icon_center"]
		var at: Vector2 = s["origin"] + ic * s["scale"]
		check(at.distance_to(row[0] * 0.5) < 1e-3, "%s 아이콘 가운데 = 화면 가운데" % str(row[0]))
		near(s["radius"] * s["scale"], 96.0 * row[1], 1e-3, "%s 원 지름 192dp" % str(row[0]))
		near(s["edge"], 0.0, 1e-6, "처음에는 가장자리가 또렷하다")
		near(s["back"], 0.0, 1e-6, "뒤 날개는 없다")
		near(s["name"], 0.0, 1e-6, "이름은 없다")


func test_final_fits_every_screen() -> void:
	var d := data()
	var g := SplashPlan.group_extent(d)
	for row in DEVICES:
		var view: Vector2 = row[0]
		var p := SplashPlan.plan(view, row[1], d)
		eq(p["k"], row[2], "%s 마지막 칸 배율" % str(view))
		var s := SplashPlan.state(p, SplashPlan.MOVE_END)
		eq(s["origin"], p["origin_final"], "%s 움직임이 끝나면 정수 자리" % str(view))
		eq(s["scale"], float(p["k"]), "%s 정수 배율" % str(view))
		var c := view * 0.5
		var k := float(p["k"])
		check(c.x + g.x * k >= 0.0 and c.x + g.z * k <= view.x, "%s 까치가 화면 폭 안" % str(view))
		check(c.y + g.y * k >= 0.0 and c.y + g.w * k <= view.y, "%s 까치와 이름이 화면 높이 안" % str(view))
		var width_share := (g.z - g.x) * k / view.x
		check(width_share <= 0.73, "%s 까치 폭 %.2f" % [str(view), width_share])


func test_reveal_grows_and_covers_magpie() -> void:
	var d := data()
	var p := SplashPlan.plan(Vector2(1080, 2400), 2.625, d)
	var prev := SplashPlan.state(p, 0.0)
	var t := 0.0
	while t <= SplashPlan.FADE_END:
		t += 1.0 / 60.0
		var s := SplashPlan.state(p, t)
		check(s["radius"] >= prev["radius"] and s["edge"] >= prev["edge"], "드러난 곳은 다시 흐려지지 않는다 (t=%.2f)" % t)
		check(s["back"] >= prev["back"] and s["name"] >= prev["name"], "뒤 날개·이름은 늘기만 한다 (t=%.2f)" % t)
		prev = s
	var end := SplashPlan.state(p, SplashPlan.REVEAL_END)
	var bb: Array = d["magpie_bbox"]
	var ic: Vector2 = p["icon_center"]
	for x in [bb[0], bb[2]]:
		for y in [bb[1], bb[3]]:
			check((Vector2(x, y) - ic).length() < end["radius"], "원이 까치 끝 (%d, %d)까지 덮는다" % [x, y])
	near(SplashPlan.state(p, SplashPlan.BACK_END)["back"], 1.0, 1e-6, "뒤 날개가 다 들어온다")
	near(SplashPlan.state(p, SplashPlan.NAME_END)["name"], 1.0, 1e-6, "이름이 다 뜬다")


func test_fade_and_skip() -> void:
	near(SplashPlan.fade(0.0), 1.0, 1e-6, "처음")
	near(SplashPlan.fade(SplashPlan.FADE_START), 1.0, 1e-6, "넘어가기 전")
	near(SplashPlan.fade(SplashPlan.FADE_END), 0.0, 1e-6, "끝")
	# 0.1초에 누르면 0.15초 뒤 사라진다
	near(SplashPlan.fade(0.1, 0.1, 1.0), 1.0, 1e-6, "누른 순간")
	near(SplashPlan.fade(0.1 + SplashPlan.SKIP_FADE, 0.1, 1.0), 0.0, 1e-6, "누르고 나서")
	# 사라지는 중에 누르면 그때 알파에서 줄어든다
	var f := SplashPlan.fade(0.78)
	check(SplashPlan.fade(0.8, 0.78, f) <= f, "사라지는 중에 눌러도 다시 밝아지지 않는다")


func test_name_language() -> void:
	eq(SplashPlan.name_lang("ko"), "ko", "한국어 기기는 새바라기")
	eq(SplashPlan.name_lang("en"), "en", "그 밖은 NearWings")
	eq(SplashPlan.name_lang("ja"), "en", "일본어도 NearWings")
	var d := data()
	check(d["names"].has("ko") and d["names"].has("en"), "이름 그림 둘")
