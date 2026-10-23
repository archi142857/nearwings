class_name TimeOfDay
extends RefCounted
## 하루 시간대. 배경은 시간대에 따라 바뀐다(결정 기록 2026-10-22). 게임 시간은 기기 시계다(2026-10-23).
## 시각(0~24시)마다 섞을 색표 두 장과 섞는 정도, 새 빛깔을 정한다. 상태가 없는 함수만 둔다 (단위 시험 대상).

## [시각, 색표]. 이웃한 두 점 사이는 부드럽게 섞는다. 새벽 5:45, 낮 7:00~17:00, 해 질 녘 18:30, 밤 20:00~4:30.
const KEYS := [
	[0.0, "night"], [4.5, "night"], [5.75, "dawn"], [7.0, "day"],
	[17.0, "day"], [18.5, "evening"], [20.0, "night"], [24.0, "night"],
]
## 새도 배경처럼 조금 물들인다 (임시. 새 색표가 생기면 바꾼다)
const BIRD_TINT := {
	"day": Color(1.0, 1.0, 1.0),
	"dawn": Color(0.93, 0.86, 0.89),
	"evening": Color(0.86, 0.76, 0.70),
	"night": Color(0.60, 0.64, 0.80),
}
const LABELS := {"night": "밤", "dawn": "새벽", "day": "낮", "evening": "저녁"}


## [색표 a, 색표 b, 섞는 정도 0~1].
static func blend(hour: float) -> Array:
	var h := fposmod(hour, 24.0)
	for i in KEYS.size() - 1:
		var h0: float = KEYS[i][0]
		var h1: float = KEYS[i + 1][0]
		if h >= h0 and h < h1:
			var t := (h - h0) / (h1 - h0)
			return [KEYS[i][1], KEYS[i + 1][1], t * t * (3.0 - 2.0 * t)]
	return ["night", "night", 0.0]


static func bird_tint(hour: float) -> Color:
	var b := blend(hour)
	return (BIRD_TINT[b[0]] as Color).lerp(BIRD_TINT[b[1]], b[2])


## 지금 시각에 더 가까운 시간대 이름 (night, dawn, day, evening).
static func phase(hour: float) -> String:
	var b := blend(hour)
	return b[0] if b[2] < 0.5 else b[1]


## 기기 시계의 지금 시각 (0~24).
static func real_hour() -> float:
	var t := Time.get_time_dict_from_system()
	return float(t["hour"]) + float(t["minute"]) / 60.0 + float(t["second"]) / 3600.0


static func format(hour: float) -> String:
	var m := int(floor(fposmod(hour, 24.0) * 60.0))
	return "%02d:%02d" % [m / 60, m % 60]
