extends "res://tests/test_case.gd"
## 시간대: 시각 → 색표 섞기, 빠른 시간(5분에 하루) 셈 (03_개발 계획 '시간대').


func test_blend_at_key_hours() -> void:
	eq(TimeOfDay.phase(12.0), "day", "정오는 낮")
	eq(TimeOfDay.phase(18.5), "evening", "18:30은 저녁")
	eq(TimeOfDay.phase(23.0), "night", "23시는 밤")
	eq(TimeOfDay.phase(2.0), "night", "2시는 밤")
	eq(TimeOfDay.phase(5.75), "dawn", "5:45는 새벽")
	var b := TimeOfDay.blend(12.0)
	eq(b[0], "day", "정오 a")
	eq(b[1], "day", "정오 b")


func test_blend_is_continuous() -> void:
	# 시각을 조금씩 옮겨도 새 빛깔이 갑자기 바뀌지 않는다 (색표가 바뀌는 점에서도)
	var prev := TimeOfDay.bird_tint(0.0)
	var h := 0.0
	while h < 24.0:
		h += 0.05
		var c := TimeOfDay.bird_tint(h)
		var d := maxf(maxf(absf(c.r - prev.r), absf(c.g - prev.g)), absf(c.b - prev.b))
		check(d < 0.03, "%.2f시에 빛깔이 튄다 (%.3f)" % [h, d])
		prev = c


func test_blend_t_in_range() -> void:
	for i in 96:
		var b := TimeOfDay.blend(i * 0.25)
		check(b[2] >= 0.0 and b[2] <= 1.0, "%.2f시 섞는 정도 %.3f" % [i * 0.25, b[2]])


func test_fast_day_is_five_minutes() -> void:
	near(TimeOfDay.fast_hour(6.0, 300.0), 6.0, 1e-6, "5분이면 하루가 지나 같은 시각")
	near(TimeOfDay.fast_hour(0.0, 150.0), 12.0, 1e-6, "2분 30초면 12시간")
	near(TimeOfDay.fast_hour(23.0, 12.5), 0.0, 1e-6, "자정을 넘으면 0시부터")


func test_format() -> void:
	eq(TimeOfDay.format(5.75), "05:45", "5.75시")
	eq(TimeOfDay.format(24.0), "00:00", "24시는 0시")
