class_name BirdRules
extends RefCounted
## 새가 오고 가는 규칙. 실제 탐조하는 느낌으로, 한 화면의 새는 0~2마리이고 2마리는 드물다(결정 기록 2026-10-22).
## 이 값들은 놀이 설정으로 바꾸지 않는다(사용자: 진짜 탐조하는 느낌의 앱이 목표). 상태가 없는 값과 함수만 둔다 (단위 시험 대상).

const MAX_BIRDS := 2            # 한 화면에 함께 있는 새 (지나가는 새 포함, 떠나는 새 빼고)
const MEAN_WAIT := 10.0         # 새가 없을 때 다음 새가 오기까지 평균 (초)
const SECOND_BIRD := 1.0 / 12.0  # 새가 한 마리 있을 때 다음 새가 오는 빠르기 = 없을 때의 1/12 (두 마리는 정말 드물게)
const PASS_CHANCE := 0.22       # 온 새 가운데 내려앉지 않고 지나가기만 하는 새의 비율
const STAY_MIN := 8.0           # 앉아 있는 시간 (초)
const STAY_MAX := 24.0


## 지금 n마리가 있을 때 1초 동안 새가 올 확률(빠르기). 화면과 상관없다.
static func arrival_rate(present: int) -> float:
	if present >= MAX_BIRDS:
		return 0.0
	return pow(SECOND_BIRD, present) / MEAN_WAIT
