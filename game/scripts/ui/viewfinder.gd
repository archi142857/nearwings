extends Control
## 뷰파인더: 네 귀퉁이 괄호(디자인 시안과 같은 모양). 선 굵기와 팔 길이는 배경 칸 기준이다.

var cell_px := 5.0
var color := Color("6f6250")


func _draw() -> void:
	var t := maxf(2.0, roundf(cell_px))        # 선 굵기 = 배경 1칸
	var arm := roundf(cell_px * 6.0)           # 팔 길이 = 배경 6칸
	var w := size.x
	var h := size.y
	# 왼쪽 위
	draw_rect(Rect2(0, 0, arm, t), color)
	draw_rect(Rect2(0, 0, t, arm), color)
	# 오른쪽 위
	draw_rect(Rect2(w - arm, 0, arm, t), color)
	draw_rect(Rect2(w - t, 0, t, arm), color)
	# 왼쪽 아래
	draw_rect(Rect2(0, h - t, arm, t), color)
	draw_rect(Rect2(0, h - arm, t, arm), color)
	# 오른쪽 아래
	draw_rect(Rect2(w - arm, h - t, arm, t), color)
	draw_rect(Rect2(w - t, h - arm, t, arm), color)
