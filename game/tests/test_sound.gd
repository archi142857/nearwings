extends "res://tests/test_case.gd"
## 소리 섞기 (SoundMix, 04_사운드 계획 '넘겨주기')와 시간대 섞기 시험 줄기.


func test_phase_weights_follow_background() -> void:
	# 낮 12시는 낮 줄기만, 0시는 밤, 5:45는 새벽, 18:30은 해 질 녘
	for row in [[12.0, 2], [0.0, 4], [5.75, 1], [18.5, 3]]:
		var w := SoundMix.stem_weights(row[0])
		near(w[row[1]], 1.0, 1e-6, "%s시 무게" % str(row[0]))
		near(w[0], 1.0, 1e-6, "바탕은 늘 1")
		var db := SoundMix.stem_db(row[0])
		near(db[row[1]], 0.0, 1e-4, "%s시 그 줄기 0dB" % str(row[0]))
	# 배경 색표와 같은 무게: 17:45는 낮과 해 질 녘이 반씩
	var w2 := SoundMix.stem_weights(17.75)
	near(w2[2], 0.5, 1e-6, "17:45 낮")
	near(w2[3], 0.5, 1e-6, "17:45 해 질 녘")
	near(SoundMix.stem_db(17.75)[2], -3.01, 0.02, "반씩 섞일 때 −3dB (같은 힘)")


func test_equal_power_and_no_nan() -> void:
	var h := 0.0
	while h < 24.0:
		var w := SoundMix.stem_weights(h)
		var power := 0.0
		for i in range(1, 5):
			power += pow(SoundMix.stem_gain(w[i]), 2.0)
		near(power, 1.0, 1e-5, "%.2f시 색깔 층 세기 합" % h)
		for v in SoundMix.stem_db(h):
			check(is_finite(v) and v >= -80.01 and v <= 0.0001, "%.2f시 음량 %s" % [h, str(v)])
		h += 0.05


func test_world_filter() -> void:
	var closed := SoundMix.world_filter(0.0)
	near(closed.x, 20000.0, 1e-3, "닫힌 가방: 저역 통과 없음")
	near(closed.y, 0.0, 1e-6, "닫힌 가방: 음량 그대로")
	var open := SoundMix.world_filter(1.0)
	near(open.x, SoundMix.MUFFLE_HZ, 1e-3, "다 연 가방: 끝값")
	near(open.y, SoundMix.MUFFLE_DB, 1e-6, "다 연 가방: 끝 음량")
	near(SoundMix.world_filter(0.5).x, sqrt(20000.0 * SoundMix.MUFFLE_HZ), 1e-2, "가운데는 기하 평균")
	check(SoundMix.MUFFLE_HZ >= 700.0 and SoundMix.MUFFLE_HZ <= 2000.0, "끝값은 사운드 세션 범위 0.7~2kHz")
	check(SoundMix.MUFFLE_DB <= -3.0 and SoundMix.MUFFLE_DB >= -9.0, "끝 음량은 −3~−9dB")


func test_demo_stems_loop_together() -> void:
	# 다섯 줄기는 길이·박자가 같고 루프여야 함께 돈다 (가져오기 설정: loop, bpm 72, 64박)
	var length := -1.0
	for name in SoundMix.STEMS:
		var s: AudioStreamOggVorbis = load("res://assets/audio/tod_demo/bgm_tod_demo_%s.ogg" % name)
		check(s != null, "%s 줄기가 있다" % name)
		if s == null:
			continue
		check(s.loop and s.loop_offset == 0.0, "%s 루프" % name)
		eq(s.bpm, 72.0, "%s bpm" % name)
		eq(s.beat_count, 64, "%s 박 수" % name)
		near(s.get_length(), 64.0 * 60.0 / 72.0, 1e-3, "%s 길이 = 16마디" % name)
		if length < 0.0:
			length = s.get_length()
		near(s.get_length(), length, 1e-6, "%s 길이가 다른 줄기와 같다" % name)
