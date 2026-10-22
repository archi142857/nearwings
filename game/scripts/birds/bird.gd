class_name Bird
extends Node2D
## 새 한 마리. position은 발끝(가지·땅에 닿는 점)이고 단위는 배경 칸이다.
## 날 때도 그림 아래쪽 가운데를 같은 기준점으로 써서, 내려앉을 때 튀지 않게 한다.
## 그림은 모두 왼쪽을 본다고 가정한다.

enum State { ARRIVING, PERCHED, LEAVING, PASSING }

const SPEED := {"undulating": 58.0, "direct": 72.0, "slow": 40.0}  # 배경 칸/초
const FLAP_HZ := {"undulating": 9.0, "direct": 6.0, "slow": 2.2}

var sp: Dictionary
var state := State.ARRIVING
var feet := Vector2.ZERO        # 실제 발끝 위치 (화면에 맞추기 전)
var p0 := Vector2.ZERO          # 비행 경로 (2차 베지어)
var p1 := Vector2.ZERO
var p2 := Vector2.ZERO
var dur := 1.0
var t := 0.0
var stay := 6.0                 # 앉아 있을 남은 시간 (초)
var idle_left := 2.0
var kind := ""                  # 앉은 횃대 종류
var facing_left := true
var flap := 0.0
var offscreen := 0.0            # 앉은 채로 화면 밖에 있던 시간
var spot := Rect2()             # 앉을 자리 (겹침 검사용, 월드 칸)
var bird_cell := 0.8            # 새 한 칸 = 배경 몇 칸 (배경 칸 1.25배면 0.8)
var step := 0.2                 # 화면 한 화소 = 배경 몇 칸
var snap_cells := false         # 칸 단위로 끊어 움직이기 (비교용)
var sprite: Sprite2D


func setup(species: Dictionary, mat: ShaderMaterial) -> void:
	sp = species
	sprite = Sprite2D.new()
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.material = mat
	add_child(sprite)


func speed() -> float:
	return float(sp.get("speed", SPEED.get(sp["flight"], 60.0)))


## 그림이 차지하는 사각형 (월드 칸).
static func rect_for(species: Dictionary, pose: String, at_feet: Vector2, cell: float) -> Rect2:
	var size := SpeciesDB.sprite_size(species, pose) * cell
	return Rect2(at_feet - Vector2(size.x * 0.5, size.y), size)


func arrive(from: Vector2, to: Vector2, perch_kind: String) -> void:
	kind = perch_kind
	var lift := clampf(from.distance_to(to) * 0.18, 6.0, 40.0)
	_fly(State.ARRIVING, from, Vector2((from.x + to.x) * 0.5, minf(from.y, to.y) - lift), to)


func leave(to: Vector2) -> void:
	var dir := signf(to.x - feet.x)
	_fly(State.LEAVING, feet, feet + Vector2(dir * 14.0, -20.0), to)


func pass_through(from: Vector2, to: Vector2) -> void:
	_fly(State.PASSING, from, (from + to) * 0.5 + Vector2(0.0, App.rng.randf_range(-10.0, 10.0)), to)


## 지금 그려진 그림이 차지하는 사각형 (월드 칸). 셔터 판정에 쓴다.
func drawn_rect() -> Rect2:
	if sprite.texture == null:
		return Rect2(position, Vector2.ZERO)
	var size := Vector2(sprite.texture.get_size()) * sprite.scale
	return Rect2(position + sprite.position, size)


func perch_now(at_feet: Vector2, perch_kind: String) -> void:
	kind = perch_kind
	feet = at_feet
	state = State.PERCHED
	facing_left = App.rng.randf() < 0.5
	stay = App.rng.randf_range(BirdRules.STAY_MIN, BirdRules.STAY_MAX)
	idle_left = App.rng.randf_range(1.5, 4.0)
	_update()


func is_flying() -> bool:
	return state != State.PERCHED


func _fly(s: State, a: Vector2, c: Vector2, b: Vector2) -> void:
	state = s
	p0 = a
	p1 = c
	p2 = b
	t = 0.0
	dur = maxf(1.0, _arc_length() / speed())
	feet = a
	facing_left = b.x < a.x
	_update()


func _bezier(u: float) -> Vector2:
	var v := 1.0 - u
	return p0 * v * v + p1 * 2.0 * v * u + p2 * u * u


func _arc_length() -> float:
	var length := 0.0
	var prev := p0
	for i in range(1, 9):
		var q := _bezier(i / 8.0)
		length += prev.distance_to(q)
		prev = q
	return length


func _process(delta: float) -> void:
	if state == State.PERCHED:
		stay -= delta
		idle_left -= delta
		if idle_left <= 0.0:
			idle_left = App.rng.randf_range(1.5, 4.0)
			if App.rng.randf() < 0.35:
				facing_left = not facing_left
	else:
		t += delta
		var x := clampf(t / dur, 0.0, 1.0)
		var u := x
		if state == State.ARRIVING:
			u = sin(x * PI * 0.5)          # 내려앉으며 느려진다
		elif state == State.LEAVING:
			u = 1.0 - cos(x * PI * 0.5)    # 날아오르며 빨라진다
		var pos := _bezier(u)
		if sp["flight"] == "undulating":   # 파도형: 날갯짓으로 오르고 날개를 접으며 내려온다
			var fade := 1.0 - x if state == State.ARRIVING else 1.0
			pos.y -= absf(sin(t * PI * 2.2)) * 2.5 * fade
		var dx := _bezier(minf(u + 0.02, 1.0)).x - _bezier(maxf(u - 0.02, 0.0)).x
		if absf(dx) > 0.01:
			facing_left = dx < 0.0
		feet = pos
		flap += delta * float(FLAP_HZ.get(sp["flight"], 6.0))
		if x >= 1.0:
			if state == State.ARRIVING:
				perch_now(p2, kind)
				facing_left = p2.x < p0.x
			else:
				queue_free()
				return
	_update()


func _update() -> void:
	var tex: Texture2D = sp["tex"]["stand"]
	var squash := 1.0
	if is_flying():
		var frames: Array = sp["tex"]["fly"]
		if frames.size() >= 2:
			tex = frames[int(flap * 2.0) % 2]
		elif frames.size() == 1:
			tex = frames[0]
		else:
			squash = 0.88 if int(flap * 2.0) % 2 == 0 else 1.0   # 임시: 날개 그림이 없을 때 날갯짓 흉내
	elif kind == "water" and sp["tex"]["swim"] != null:
		tex = sp["tex"]["swim"]
	sprite.texture = tex
	var size := Vector2(tex.get_size())
	sprite.scale = Vector2(bird_cell, bird_cell * squash)
	sprite.flip_h = not facing_left
	sprite.position = -Vector2(size.x * 0.5 * bird_cell, size.y * bird_cell * squash)
	# 그릴 때는 그림 왼쪽 위를 화소 단위(또는 새 칸 단위)에 맞춘다
	var s := bird_cell if snap_cells else step
	var top_left := (feet + sprite.position).snapped(Vector2(s, s))
	position = top_left - sprite.position
