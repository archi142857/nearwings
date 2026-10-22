extends Node2D
## 가방 둘레 바닥에 지는 옅은 그림자: 가방 가장자리에서 cells칸까지 칸 단위로 옅어진다 (단위: 가방 칸).
## 시안에서 잰 값: 가장자리 바로 옆이 바닥보다 11% 어둡고 6칸쯤 가면 사라진다.

var size := Vector2.ZERO
var cells := 6
var strength := 0.11


func _draw() -> void:
	for i in range(1, cells + 1):
		var a := strength * (1.0 - float(i - 1) / float(cells))
		var c := Color(0.12, 0.10, 0.06, a)
		var r := Rect2(Vector2(-i, -i), size + Vector2(2 * i, 2 * i))
		# 고리 한 칸 두께: 위, 아래, 왼쪽, 오른쪽
		draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), c)
		draw_rect(Rect2(Vector2(r.position.x, r.end.y - 1), Vector2(r.size.x, 1)), c)
		draw_rect(Rect2(Vector2(r.position.x, r.position.y + 1), Vector2(1, r.size.y - 2)), c)
		draw_rect(Rect2(Vector2(r.end.x - 1, r.position.y + 1), Vector2(1, r.size.y - 2)), c)
