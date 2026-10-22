extends Sprite2D
## 서식지 배경 한 벌. 1칸 = 장면 좌표 1.
## 서식지마다 세로형·정사각형·가로형 세 벌(portrait, square, landscape 폴더)이 있고 색표(palettes.json)는 하나다.
## 원본은 벌마다 index.png(칸마다 색 번호)이고, tools/bake_palettes.py가 색표마다 baked_<이름>.png로 구워 둔다.
## 화면에는 구운 그림을 그리고, 시간대가 바뀌는 사이는 이웃한 두 시간대 그림을 섞는다(TimeOfDay).
## (SubViewport로 실행 중에 굽는 방법은 Compatibility 렌더러에서 색이 어두워져 쓰지 않는다.)

var habitat_dir := ""
var palette_order: Array = []
var mat: ShaderMaterial
var textures := {}        # 지금 벌의 색표 이름 → 구운 그림
var shown := ["", ""]     # 지금 섞고 있는 두 색표


func setup(dir: String) -> void:
	habitat_dir = dir
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + "/palettes.json"))
	palette_order = data["order"]
	centered = false
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	z_index = -10
	mat = ShaderMaterial.new()
	mat.shader = preload("res://shaders/bg_mix.gdshader")
	material = mat


## 이 서식지에 있는 벌과 장면 크기(칸): {벌 이름: Vector2}.
func set_sizes() -> Dictionary:
	var out := {}
	for s in Layout.SET_NAMES:
		var path := "%s/%s/baked_%s.png" % [habitat_dir, s, palette_order[0]]
		if ResourceLoader.exists(path):
			out[s] = Vector2((load(path) as Texture2D).get_size())
	return out


func use_set(set_id: String) -> void:
	textures.clear()
	for p in palette_order:
		textures[p] = load("%s/%s/baked_%s.png" % [habitat_dir, set_id, p])
	shown = ["", ""]
	_show(palette_order[0], palette_order[0], 0.0)


func scene_size() -> Vector2:
	return Vector2(texture.get_size())


## 시각(0~24시)에 맞는 색으로 그린다. 없는 색표는 낮 색표로 대신한다.
func set_time(hour: float) -> void:
	var b := TimeOfDay.blend(hour)
	_show(b[0], b[1], b[2])


func _show(a: String, b: String, t: float) -> void:
	if not textures.has(a):
		a = palette_order[0]
	if not textures.has(b):
		b = palette_order[0]
	if a != shown[0]:
		texture = textures[a]
	if b != shown[1]:
		mat.set_shader_parameter("tex_b", textures[b])
	shown = [a, b]
	mat.set_shader_parameter("mix_ab", clampf(t, 0.0, 1.0))


func set_smooth(on: bool) -> void:
	mat.set_shader_parameter("smooth_edges", on)
