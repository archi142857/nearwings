extends Node2D
## 가방 둘레 바닥에 지는 그림자 (디자인 배치값 'bag_shadow_on_ground', assets/bag/bag.json 'bag_shadow').
## 가방 모양을 max_filter_px만큼 넓혀 blur_px로 흐린 것을 바닥에 곱한다(shaders/bag_shadow.gdshader).
## 세기는 strength × max(흐림 정도, min_focus): 닫혀 있을 때도 윗단 둘레에 옅게 진다.
## 가방(bag_root) 아래에 두므로 단위는 가방 칸이다. 시안 화소 → 가방 칸은 5화소로 나눈다.

var size := Vector2.ZERO          # 가방 크기 (가방 칸)
var grow := 0.8                   # 넓히는 양 (max filter 9화소 → 반지름 4화소)
var sigma := 3.2                  # 흐림 (16화소)
var mat: ShaderMaterial


func setup(d: Dictionary) -> void:
	var cell := float(d["bag_cell_px"])
	grow = floorf(float(d["bag_shadow"]["max_filter_px"]) * 0.5) / cell
	sigma = float(d["bag_shadow"]["blur_px"]) / cell
	mat = ShaderMaterial.new()
	mat.shader = preload("res://shaders/bag_shadow.gdshader")
	mat.set_shader_parameter("grow", grow)
	mat.set_shader_parameter("sigma", sigma)
	material = mat


func set_size(s: Vector2) -> void:
	size = s
	mat.set_shader_parameter("rect_size", s)
	queue_redraw()


func set_strength(v: float) -> void:
	mat.set_shader_parameter("strength", v)


func _draw() -> void:
	var m := grow + 4.0 * sigma
	draw_rect(Rect2(-Vector2(m, m), size + Vector2(2.0 * m, 2.0 * m)), Color.WHITE)
