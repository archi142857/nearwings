extends CanvasLayer
## 가방 메뉴 (결정 기록 2026-10-22: 위로 밀면 시선이 내려가며 가방 속을 들여다본다. 이 화면이 메뉴다).
## 기본 화면 맨 아래에는 가방 윗단과 화살표 둘만 보인다(누르는 곳이 아니라 '아래에 가방이 있다'는 표시).
## 위로 밀면 손가락을 따라 공원과 발밑 바닥이 올라가고(main이 look만큼 카메라를 내린다), 가방은 조금 늦게 따라온다.
## 1/4 넘게 밀고 놓으면 0.45초 동안 끝까지 열리고, 덜 밀면 되돌아간다. 열리면 도구가 차례로 떴다 앉고 이름표가 뜬다.
## 닫기: 아래로 밀기, 뒤로 가기, 위쪽 흐린 바닥 누르기. 닫을 때는 이름표가 먼저 사라진다.
## 그림과 자리는 디자인 캔버스 '가방 메뉴' 시안에서 뽑은 임시 그림(assets/bag, tools/bag_import.py), 배치는 BagLayout.

signal chosen(id: String)   # 도구를 눌렀다 (dogam, binoculars, camera)
signal closed               # 끝까지 닫혔다

enum Phase { CLOSED, DRAG, OPENING, OPEN, CLOSING }

const DIR := "res://assets/bag"
const OPEN_SEC := 0.45
const CLOSE_SEC := 0.32
const OPEN_SHARE := 0.25          # 이만큼 넘게 밀고 놓으면 끝까지 열린다
const LIFT_LAG := 0.06            # 가방이 손가락보다 늦게 따라오는 정도
const OVERSHOOT := 1.6            # 가방이 자리에서 살짝 넘치는 정도 (ease-out-back)
const HOP_GAP := 0.06             # 도구가 차례로 떴다 앉는 간격
const HOP_SEC := 0.18
const HOP_CELLS := 1.6            # 떴다 앉는 높이 (가방 칸 = 도구 2칸)
const PRESS_CELLS := 0.8          # 누르면 한 칸(도구 칸) 떠오른다
const TAG_FADE := 0.12

var main: Node
var data := {}
var lay := {}                     # BagLayout.compute 결과
var base_img: Image
var sharp_mat: ShaderMaterial
var shadow_mat: ShaderMaterial
var root: Node2D                  # 화면 화소 좌표
var bag_root: Node2D              # 가방 왼쪽 위, 가방 칸 단위 (scale = 가방 한 칸 화소)
var shade: Node2D                 # 가방 둘레 바닥 그림자
var bag_sprite: Sprite2D
var arrows: Sprite2D
var items := {}                   # id → {shadow, art, tag, rect}
var order: Array[String] = []

var phase := Phase.CLOSED
var look := 0.0                   # 0 = 공원을 본다, 1 = 발밑을 본다
var lift := 0.0                   # 가방 자리: 0 = 닫힘(윗단만), 1 = 열림
var tags_a := 0.0
var anim_t := 0.0
var from_look := 0.0
var from_lift := 0.0
var hop_t := -1.0
var pressed := ""
var frozen := false               # --bag=<0~1>: 화면 캡처용으로 그 자리에 멈춘다


func setup(main_node: Node, mat: ShaderMaterial) -> void:
	main = main_node
	layer = 3
	sharp_mat = mat
	shadow_mat = mat.duplicate()
	shadow_mat.set_shader_parameter("silhouette", 1.0)
	data = JSON.parse_string(FileAccess.get_file_as_string(DIR + "/bag.json"))
	shadow_mat.set_shader_parameter("silhouette_color", Color(String(data["tool_shadow"]["color"])))
	base_img = (load(DIR + "/" + String(data["bag"]["file"])) as Texture2D).get_image()

	root = Node2D.new()
	add_child(root)
	bag_root = Node2D.new()
	root.add_child(bag_root)
	shade = preload("res://scripts/ui/bag_shade.gd").new()
	shade.cells = int(data["bag_shadow"]["cells"])
	shade.strength = float(data["bag_shadow"]["strength"])
	bag_root.add_child(shade)
	bag_sprite = _sprite(null, sharp_mat)
	bag_root.add_child(bag_sprite)
	for t in data["tools"]:
		var id := String(t["id"])
		var art_tex := _tex(t["art"])
		var it := {
			"shadow": _sprite(art_tex, shadow_mat),
			"art": _sprite(art_tex, sharp_mat),
			"tag": _sprite(_tex(t["tag"]), sharp_mat),
			"art_k": _cell_k(t["art"]),
			"tag_k": _cell_k(t["tag"]),
		}
		for key in ["shadow", "art", "tag"]:
			bag_root.add_child(it[key])
		items[id] = it
		order.append(id)
	arrows = _sprite(_tex("arrows"), sharp_mat)
	root.add_child(arrows)

	if App.args.has("bag"):
		frozen = true
		look = clampf(float(App.args["bag"]), 0.0, 1.0)
		lift = look
		phase = Phase.OPEN if look >= 1.0 else (Phase.CLOSED if look <= 0.0 else Phase.DRAG)
		tags_a = 1.0 if phase == Phase.OPEN else 0.0


func _tex(key: String) -> Texture2D:
	return load(DIR + "/" + String(data["pieces"][key]["file"]))


## 이 그림 한 칸이 가방 몇 칸인지 (도구 0.8, 이름표 0.2).
func _cell_k(key: String) -> float:
	return float(data["pieces"][key]["px_per_cell"]) / BagLayout.DESIGN_PX


func _sprite(tex: Texture2D, mat: Material) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	s.material = mat
	return s


## 화면 크기가 바뀌면 배치를 다시 셈하고 가방 그림을 다시 만든다.
func on_resized() -> void:
	var view: Vector2 = main.view_cells
	lay = BagLayout.compute(view, data)
	var img := BagLayout.build_image(base_img, lay, data)
	bag_sprite.texture = ImageTexture.create_from_image(img)
	shade.size = Vector2(img.get_size())
	shade.queue_redraw()
	for it in lay["items"]:
		var n: Dictionary = items[it["id"]]
		n["rect"] = it["art"].merge(it["tag"])
		var art: Rect2 = it["art"]
		var tag: Rect2 = it["tag"]
		n["art_pos"] = art.position
		n["tag_pos"] = tag.position
		for key in ["shadow", "art"]:
			n[key].scale = Vector2.ONE * float(n["art_k"])
		n["tag"].scale = Vector2.ONE * float(n["tag_k"])
	_place()


## 가방 한 칸이 화면 몇 화소인지.
func cell_px() -> float:
	return float(main.bg_px) * float(lay.get("s", 1.0))


func _place() -> void:
	if lay.is_empty():
		return
	var px: float = main.bg_px
	var c := cell_px()
	var open_pos: Vector2 = lay["open_pos"]
	var closed_pos: Vector2 = lay["closed_pos"]
	var y := lerpf(closed_pos.y, open_pos.y, lift)
	bag_root.position = (Vector2(open_pos.x, y) * px).round()
	bag_root.scale = Vector2.ONE * c
	var sh: Array = data["tool_shadow"]["offset_cells"]
	var sh_off := Vector2(float(sh[0]), float(sh[1])) * float(data["tool_cell_px"]) / BagLayout.DESIGN_PX   # 도구 칸 → 가방 칸
	for i in order.size():
		var id := order[i]
		var n: Dictionary = items[id]
		var up := 0.0
		if id == pressed:
			up = PRESS_CELLS
		elif hop_t >= 0.0:
			var u := (hop_t - HOP_GAP * i) / HOP_SEC
			if u > 0.0 and u < 1.0:
				up = HOP_CELLS * sin(PI * u)
		n["shadow"].position = n["art_pos"] + sh_off
		n["art"].position = n["art_pos"] - Vector2(0.0, up)
		n["tag"].position = n["tag_pos"] - Vector2(0.0, up)
		var a := tags_a
		if hop_t >= 0.0:
			a = minf(a, clampf((hop_t - HOP_GAP * i) / TAG_FADE, 0.0, 1.0))
		n["tag"].modulate.a = a
	var asz: Vector2 = lay["arrows_size"]
	arrows.position = (Vector2(lay["arrows_pos"]) * px + Vector2(0.0, (open_pos.y - closed_pos.y) * px * lift)).round()   # 가방과 함께 올라간다
	arrows.scale = Vector2.ONE * (asz.x * px / float(arrows.texture.get_width()))
	arrows.modulate.a = clampf(1.0 - look * 4.0, 0.0, 1.0)


func _process(delta: float) -> void:
	if frozen:
		_place()
		return
	match phase:
		Phase.OPENING:
			anim_t += delta
			var u := clampf(anim_t / OPEN_SEC, 0.0, 1.0)
			look = lerpf(from_look, 1.0, _ease_out(u))
			var v := clampf((anim_t - LIFT_LAG) / (OPEN_SEC + LIFT_LAG), 0.0, 1.0)
			lift = lerpf(from_lift, 1.0, _back_out(v))
			if v >= 1.0:
				lift = 1.0
				phase = Phase.OPEN
				hop_t = 0.0
				tags_a = 1.0
		Phase.OPEN:
			if hop_t >= 0.0:
				hop_t += delta
				if hop_t > HOP_GAP * order.size() + HOP_SEC:
					hop_t = -1.0
		Phase.CLOSING:
			anim_t += delta
			tags_a = minf(tags_a, clampf(1.0 - anim_t / 0.08, 0.0, 1.0))   # 이름표가 먼저 사라진다
			var u := clampf((anim_t - 0.06) / CLOSE_SEC, 0.0, 1.0)
			look = lerpf(from_look, 0.0, _ease_in_out(u))
			lift = lerpf(from_lift, 0.0, _ease_in_out(clampf(u * 1.08, 0.0, 1.0)))
			if u >= 1.0:
				look = 0.0
				lift = 0.0
				phase = Phase.CLOSED
				closed.emit()
	_place()


static func _ease_out(u: float) -> float:
	return 1.0 - pow(1.0 - u, 3.0)


static func _ease_in_out(u: float) -> float:
	return u * u * (3.0 - 2.0 * u)


## 끝에서 살짝 넘쳤다가 돌아오는 곡선.
static func _back_out(u: float) -> float:
	var c1 := OVERSHOOT
	var c3 := c1 + 1.0
	var t := u - 1.0
	return 1.0 + c3 * t * t * t + c1 * t * t


# ---- main이 부르는 것 ----

func is_closed() -> bool:
	return phase == Phase.CLOSED


## 완전히 열려 도구를 고를 수 있는지.
func is_open() -> bool:
	return phase == Phase.OPEN


## 공원이 조금이라도 가려졌는지 (뷰파인더와 셔터를 숨긴다).
func is_busy() -> bool:
	return phase != Phase.CLOSED


func begin_drag() -> void:
	phase = Phase.DRAG
	hop_t = -1.0
	tags_a = 0.0
	pressed = ""


## p: 0 = 닫힘, 1 = 열림. 가방은 손가락보다 조금 늦게 따라온다.
func drag_to(p: float) -> void:
	look = clampf(p, 0.0, 1.0)
	lift = clampf((look - LIFT_LAG) / (1.0 - LIFT_LAG), 0.0, 1.0)


## 손을 뗐다: opening이면 1/4 넘게 밀었을 때, 아니면(닫는 중) 1/4 넘게 내렸을 때 넘어간다.
func end_drag(opening: bool) -> void:
	if phase != Phase.DRAG:   # 끄는 중에 뒤로 가기 등으로 이미 닫히는 중이면 그대로 둔다
		return
	var go_open := look > OPEN_SHARE if opening else look > 1.0 - OPEN_SHARE
	if go_open:
		open()
	else:
		close()


func open() -> void:
	if phase == Phase.OPEN or phase == Phase.OPENING:
		return
	from_look = look
	from_lift = lift
	anim_t = 0.0
	tags_a = 0.0
	phase = Phase.OPENING


func close() -> void:
	if phase == Phase.CLOSED or phase == Phase.CLOSING:
		return
	from_look = look
	from_lift = lift
	anim_t = 0.0
	pressed = ""
	hop_t = -1.0
	phase = Phase.CLOSING


## 뒤로 가기: 열려 있거나 움직이는 중이면 닫는다. 닫은 것이 있으면 true.
func back() -> bool:
	if phase == Phase.CLOSED or phase == Phase.CLOSING:
		return false
	close()
	return true


## 열린 가방에서 이 화면 점에 있는 도구 (그림이나 이름표). 없으면 "".
func tool_at(p: Vector2) -> String:
	if phase != Phase.OPEN:
		return ""
	var pad: float = UiStyle.dp(6, App.density())
	for id in order:
		var r: Rect2 = items[id]["rect"]
		var screen := Rect2(bag_root.position + r.position * cell_px(), r.size * cell_px()).grow(pad)
		if screen.has_point(p):
			return id
	return ""


## 가방 윗단(화면 화소). 이보다 위는 흐린 바닥이다.
func top_px() -> float:
	return bag_root.position.y


## 닫힌 가방 위 화살표의 윗변(화면 화소): 셔터를 이보다 위에 둔다.
func hint_top_px() -> float:
	if lay.is_empty():
		return float(main.view_px.y)
	return float(lay["arrows_pos"].y) * float(main.bg_px)


func press(id: String) -> void:
	pressed = id


## 누른 도구에서 손을 뗐다. on_item이면 고른 것으로 친다.
func release(on_item: bool) -> void:
	var id := pressed
	pressed = ""
	if on_item and id != "":
		chosen.emit(id)


## 화면 캡처·자체 시험용: 이 도구의 화면 가운데.
func item_center(id: String) -> Vector2:
	var r: Rect2 = items[id]["rect"]
	return bag_root.position + r.get_center() * cell_px()


## 화면 캡처·자체 시험용: 가방이 화면에서 차지하는 곳 (화소).
func bag_rect_px() -> Rect2:
	return Rect2(bag_root.position, Vector2(lay["size"]) * cell_px())
