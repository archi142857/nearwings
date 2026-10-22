extends "res://tests/test_case.gd"
## 새 수: 한 화면에 0~2마리, 2마리는 드물게 (결정 기록 2026-10-22, 실제 탐조하는 느낌).
## 오는 빠르기(BirdRules.arrival_rate)와 머무는 시간(BirdRules.STAY_*)으로 오래 흉내 내서 몇 마리가 보이는지 센다.


func test_arrival_rate_caps_at_two() -> void:
	near(BirdRules.arrival_rate(0), 1.0 / BirdRules.MEAN_WAIT, 1e-9, "없을 때")
	check(BirdRules.arrival_rate(1) < BirdRules.arrival_rate(0) * 0.2, "한 마리 있을 때는 훨씬 드물게")
	eq(BirdRules.arrival_rate(2), 0.0, "두 마리면 더 오지 않는다")


func test_visible_count_mostly_zero_or_one() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var dt := 0.25
	var arrive_t := 3.0      # 날아와 앉기까지 (상한에 센다)
	var leave_t := 2.5       # 앉았던 새가 떠나며 보이는 시간 (상한에는 안 센다)
	var pass_t := 5.0        # 지나가는 새가 보이는 시간 (상한에 센다)
	var birds: Array = []    # [남은 시간, 상태] 상태: "stay"(오고 앉음), "pass", "leave"
	var time_at := [0.0, 0.0, 0.0, 0.0]
	var total := 0.0
	for step in 200000:
		var counted := 0
		for b in birds:
			counted += int(b[1] != "leave")
		if rng.randf() < BirdRules.arrival_rate(counted) * dt:
			if rng.randf() < BirdRules.PASS_CHANCE:
				birds.append([pass_t, "pass"])
			else:
				birds.append([arrive_t + rng.randf_range(BirdRules.STAY_MIN, BirdRules.STAY_MAX), "stay"])
		var next: Array = []
		for b in birds:
			b[0] -= dt
			if b[0] > 0.0:
				next.append(b)
			elif b[1] == "stay":
				next.append([leave_t, "leave"])
		birds = next
		time_at[mini(birds.size(), 3)] += dt
		total += dt
	var p0: float = time_at[0] / total
	var p1: float = time_at[1] / total
	var p2: float = time_at[2] / total
	var p3: float = time_at[3] / total
	print("  보이는 새: 0마리 %.0f%%, 1마리 %.0f%%, 2마리 %.0f%%, 3마리 %.1f%%" % [p0 * 100, p1 * 100, p2 * 100, p3 * 100])
	check(p0 > 0.2 and p0 < 0.5, "새가 없는 때 %.2f (0.2~0.5)" % p0)
	check(p1 > 0.4, "한 마리인 때 %.2f (0.4 넘게)" % p1)
	check(p2 + p3 < 0.08, "두 마리 넘는 때 %.3f (정말 드물게)" % (p2 + p3))
	check(p3 < 0.02, "세 마리인 때 %.3f" % p3)
