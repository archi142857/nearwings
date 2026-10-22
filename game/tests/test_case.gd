extends RefCounted
## 단위 시험의 바탕. 실패를 모아 두었다가 실행기(run_tests.gd)가 보고한다.

var failures: Array[String] = []
var current := ""


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append("%s: %s" % [current, msg])


func eq(a: Variant, b: Variant, msg := "") -> void:
	check(a == b, "%s (값 %s, 기대 %s)" % [msg, str(a), str(b)])


func near(a: float, b: float, eps: float, msg := "") -> void:
	check(absf(a - b) <= eps, "%s (값 %s, 기대 %s ± %s)" % [msg, str(a), str(b), str(eps)])
