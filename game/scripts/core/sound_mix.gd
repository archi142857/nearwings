class_name SoundMix
extends RefCounted
## 소리 섞기 계산. 상태가 없는 함수만 둔다 (단위 시험 대상). 방식은 `04_사운드 계획.md` '넘겨주기'를 따른다.
##
## 공원 음악은 한 곡을 다섯 줄기로 만든다: 0 바탕(늘 0dB), 1 새벽, 2 낮, 3 해 질 녘, 4 밤(색깔 층).
## 색깔 층의 무게 w는 배경 색표를 섞는 TimeOfDay.blend와 같다(색표 a에 1 − t, b에 t, 나머지 0).
## 음량은 같은 힘 곡선 g = sin(w·π/2)로 바꾼다. 두 층이 섞이는 동안 g² 합이 1이라 전체 세기가 그대로다.
## 가방을 들여다보면(흐림 정도 a) 공원 소리가 World 버스에서 먹먹해진다: 저역 통과 cutoff = 20000 × (끝값/20000)^a,
## 음량 a × 끝 음량. 끝값은 사운드 세션이 들어 보고 정한다(0.7~2kHz, −3~−9dB). 지금은 가운데 값을 임시로 쓴다.

const STEMS := ["bed", "dawn", "day", "evening", "night"]
const FLOOR := 0.0001          # linear_to_db(0)은 -inf라 모든 소리가 꺼진다(Godot 이슈 #88133). −80dB에서 막는다
const OPEN_HZ := 20000.0       # 가방을 닫았을 때 저역 통과(사실상 끔)
const MUFFLE_HZ := 1000.0      # 가방을 다 열었을 때 (임시)
const MUFFLE_DB := -6.0        # 그때 공원 소리 음량 (임시)


## 줄기마다 무게 (바탕은 1).
static func stem_weights(hour: float) -> PackedFloat32Array:
	var b := TimeOfDay.blend(hour)
	var w := PackedFloat32Array([1.0, 0.0, 0.0, 0.0, 0.0])
	var t: float = b[2]
	w[STEMS.find(b[0])] += 1.0 - t
	w[STEMS.find(b[1])] += t
	w[0] = 1.0
	return w


## 무게 → 음량 배율 (같은 힘 곡선).
static func stem_gain(weight: float) -> float:
	return sin(clampf(weight, 0.0, 1.0) * PI * 0.5)


## 줄기마다 음량(dB). 바탕은 0dB, 색깔 층은 −80dB 아래로 가지 않는다.
static func stem_db(hour: float) -> PackedFloat32Array:
	var w := stem_weights(hour)
	var out := PackedFloat32Array()
	for i in STEMS.size():
		out.append(0.0 if i == 0 else linear_to_db(maxf(stem_gain(w[i]), FLOOR)))
	return out


## 가방 흐림 정도 a(0~1) → World 버스 (저역 통과 Hz, 음량 dB).
static func world_filter(a: float, end_hz := MUFFLE_HZ, end_db := MUFFLE_DB) -> Vector2:
	a = clampf(a, 0.0, 1.0)
	return Vector2(OPEN_HZ * pow(end_hz / OPEN_HZ, a), end_db * a)
