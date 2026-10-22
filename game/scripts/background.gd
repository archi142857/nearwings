extends Sprite2D
## 서식지 배경 한 벌. 1칸 = 장면 좌표 1.
## 서식지마다 세로형·정사각형·가로형 세 벌(portrait, square, landscape 폴더)이 있고 색표(palettes.json)는 하나다.
## 원본은 벌마다 index.png(칸마다 색 번호)이고, tools/bake_palettes.py가 색표마다 baked_<이름>.png로 구워 둔다.
## 화면에는 구운 그림을 그리고, 시간대가 바뀌는 사이는 이웃한 두 시간대 그림을 섞는다(TimeOfDay).
## 장면 바로 아래에는 발밑 바닥(ground_<색표>.png)이 이어진다. 가방 메뉴를 열면 시선이 내려가 이 바닥이 보이고,
## 흐린 바닥(ground_blur_<색표>.png)이 점점 겹쳐진다(set_look).
## (SubViewport로 실행 중에 굽는 방법은 Compatibility 렌더러에서 색이 어두워져 쓰지 않는다.)

var habitat_dir := ""
var palette_order: Array = []
var layers := {}          # 이름 → {sprite, mat, textures: {색표: 그림}, shown: [a, b]}  (scene, ground, ground_blur)
var set_id := ""


func setup(dir: String) -> void:
	habitat_dir = dir
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + "/palettes.json"))
	palette_order = data["order"]
	centered = false
	z_index = -10
	_add_layer("scene", self)
	for name in ["ground", "ground_blur"]:
		var s := Sprite2D.new()
		s.centered = false
		add_child(s)
		_add_layer(name, s)
	layers["ground_blur"]["sprite"].modulate.a = 0.0


func _add_layer(name: String, s: Sprite2D) -> void:
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/bg_mix.gdshader")
	s.material = mat
	layers[name] = {"sprite": s, "mat": mat, "textures": {}, "shown": ["", ""]}


## 이 서식지에 있는 벌과 장면 크기(칸): {벌 이름: Vector2}.
func set_sizes() -> Dictionary:
	var out := {}
	for s in Layout.SET_NAMES:
		var path := "%s/%s/baked_%s.png" % [habitat_dir, s, palette_order[0]]
		if ResourceLoader.exists(path):
			out[s] = Vector2((load(path) as Texture2D).get_size())
	return out


func use_set(id: String) -> void:
	set_id = id
	var files := {"scene": "baked_%s.png", "ground": "ground_%s.png", "ground_blur": "ground_blur_%s.png"}
	for name in layers:
		var L: Dictionary = layers[name]
		L["textures"] = {}
		for p in palette_order:
			var path := "%s/%s/%s" % [habitat_dir, id, files[name] % p]
			if ResourceLoader.exists(path):
				L["textures"][p] = load(path)
		L["shown"] = ["", ""]
		L["sprite"].visible = not L["textures"].is_empty()
	_show(palette_order[0], palette_order[0], 0.0)
	set_ground_top(scene_size().y)


## 발밑 바닥이 시작하는 줄(장면 좌표). 화면이 장면보다 낮아 아래가 잘리는 기기에서는 보이는 공원 바로 아래에서 시작해,
## 시선이 화면 높이만큼 내려가면 바닥만 보이게 한다 (main이 정한다).
func set_ground_top(y: float) -> void:
	for name in ["ground", "ground_blur"]:
		layers[name]["sprite"].position = Vector2(0.0, y)


func scene_size() -> Vector2:
	return Vector2(texture.get_size())


## 시각(0~24시)에 맞는 색으로 그린다. 없는 색표는 낮 색표로 대신한다.
func set_time(hour: float) -> void:
	var b := TimeOfDay.blend(hour)
	_show(b[0], b[1], b[2])


## 가방 메뉴로 시선이 내려간 정도(0~1): 발밑 바닥이 그만큼 흐려진다. 어두워지는 것은 main이 modulate로 한다.
func set_look(p: float) -> void:
	layers["ground_blur"]["sprite"].modulate.a = clampf(p, 0.0, 1.0)


func _show(a: String, b: String, t: float) -> void:
	for name in layers:
		var L: Dictionary = layers[name]
		var tex: Dictionary = L["textures"]
		if tex.is_empty():
			continue
		var la := a if tex.has(a) else String(palette_order[0])
		var lb := b if tex.has(b) else String(palette_order[0])
		var shown: Array = L["shown"]
		if la != shown[0]:
			L["sprite"].texture = tex[la]
		if lb != shown[1]:
			L["mat"].set_shader_parameter("tex_b", tex[lb])
		L["shown"] = [la, lb]
		L["mat"].set_shader_parameter("mix_ab", clampf(t, 0.0, 1.0))


## 지금 그리고 있는 장면 색표 두 장 (자체 시험용).
func shown() -> Array:
	return layers["scene"]["shown"]


func set_smooth(on: bool) -> void:
	for name in layers:
		layers[name]["mat"].set_shader_parameter("smooth_edges", on)
