class_name BirdSpawner
extends Node
## 새를 정해진 수만큼 유지한다.
## 어떤 새가 언제 오는지, 한 번에 몇 마리까지인지는 화면과 상관없이 정한다. 그래야 기기마다 새가 오는 확률이 같다
## (결정 기록 2026-10-22). 온 새는 지금 보이는 횃대 가운데 그 새가 앉을 수 있는 곳에 앉고,
## 자리가 없으면 다른 새로 바꾸지 않고 자리가 날 때까지 기다린다.
## 그래서 배경 세 벌 모두 화면에 늘 보이는 곳(안전 영역)에 그 서식지 새들이 앉을 횃대가 다 있어야 한다(tools/perch_check.py).

const MARGIN := 3.0             # 화면 가장자리에서 띄울 칸
const OFFSCREEN_LIMIT := 8.0    # 앉은 새가 화면 밖에 이만큼 있으면 치운다 (초)
const PASS_CHANCE := 0.22       # 내려앉지 않고 지나가기만 하는 새의 비율
const WAIT_LIMIT := 20.0        # 앉을 자리를 이만큼 못 찾으면 그 새는 안 온 것으로 친다 (초, 자료가 틀렸을 때만)

var main: Node                  # view_rect(), play_rect(), bird_cell(), pixel_step() 제공
var layer: Node2D
var db: SpeciesDB
var perches: Perches
var mat: ShaderMaterial
var cooldown := 0.4
var waiting: Dictionary = {}    # 오기로 정했지만 아직 앉을 자리를 못 찾은 새 (종)
var waited := 0.0


func setup(main_node: Node, bird_layer: Node2D, species_db: SpeciesDB, sharp_material: ShaderMaterial) -> void:
	main = main_node
	layer = bird_layer
	db = species_db
	mat = sharp_material


## 지금 장면(벌)의 횃대.
func use_perches(p: Perches) -> void:
	perches = p


func active_birds() -> Array[Bird]:
	var out: Array[Bird] = []
	for c in layer.get_children():
		if c is Bird and not c.is_queued_for_deletion():
			out.append(c)
	return out


## 다음에 올 새: 화면과 상관없이 종 목록에서 고른다. 지금은 모두 같은 확률이고, 출현표가 생기면 그 무게를 쓴다.
func next_species() -> Dictionary:
	return db.list[App.rng.randi_range(0, db.list.size() - 1)]


## 이 새가 지금 앉을 수 있는 자리 하나: {at: 발끝, perch: 횃대, rect: 그림 자리}. 없으면 빈 사전.
func find_spot(sp: Dictionary, inner: Rect2, tries := 40) -> Dictionary:
	var cands: Array[Dictionary] = []
	for p in perches.for_species(sp, SpeciesDB.sprite_size(sp, "stand").x):
		if p["kind"] == "water" and sp["tex"]["swim"] == null:
			continue
		if inner.intersects(Perches.bounds(p).grow(1.0)):
			cands.append(p)
	if cands.is_empty():
		return {}
	var cell: float = main.bird_cell()
	for i in tries:
		var p: Dictionary = cands[App.rng.randi_range(0, cands.size() - 1)]
		var at := Perches.point_on(p, App.rng) + Vector2(0.0, 0.6)   # 발이 가지 윗면에 살짝 걸치게
		var r := Bird.rect_for(sp, "swim" if p["kind"] == "water" else "stand", at, cell)
		if inner.encloses(r) and not _occupied(r):
			return {"at": at, "perch": p, "rect": r}
	return {}


## 화면 캡처용: 새를 처음부터 앉혀 두고 한 마리는 날게 한다.
func prewarm() -> void:
	var view: Rect2 = main.view_rect()
	var tries := 0
	while active_birds().size() < int(App.settings["bird_count"]) and tries < 40:
		tries += 1
		_spawn(view, true)
	var b := _spawn_passer(view)
	if b != null:
		b.t = b.dur * 0.45
		b._process(0.0)


## 벌이 바뀌었을 때(회전·접기·창 크기): 앉아 있던 새는 새 장면에서 자리를 다시 찾아 그대로 앉히고, 날던 새는 치운다.
func reseat() -> void:
	var keep: Array[Bird] = []
	for b in active_birds():
		if b.state == Bird.State.PERCHED:
			b.spot = Rect2()
			keep.append(b)
		else:
			b.queue_free()
	var inner: Rect2 = main.play_rect().grow(-MARGIN)
	for b in keep:
		var s := find_spot(b.sp, inner)
		if s.is_empty():
			b.queue_free()
			continue
		b.spot = s["rect"]
		b.perch_now(s["at"], s["perch"]["kind"])


func _process(delta: float) -> void:
	var view: Rect2 = main.view_rect()
	var excess := -int(App.settings["bird_count"])
	for b in active_birds():
		if b.state != Bird.State.LEAVING:
			excess += 1
	for b in active_birds():
		b.bird_cell = main.bird_cell()
		b.step = main.pixel_step()
		b.snap_cells = bool(App.settings["snap_motion"])
		if b.state == Bird.State.PERCHED:
			b.spot = Bird.rect_for(b.sp, "swim" if b.kind == "water" else "stand", b.feet, b.bird_cell)
			if view.intersects(b.spot):
				b.offscreen = 0.0
			else:
				b.offscreen += delta
				if b.offscreen > OFFSCREEN_LIMIT:
					b.queue_free()
					continue
			if b.stay <= 0.0 or excess > 0:
				excess -= 1
				b.leave(_exit_point(view, b.feet))
	if not waiting.is_empty():
		waited += delta
		if waited > WAIT_LIMIT:
			push_warning("%s: 앉을 자리를 %d초 동안 못 찾았다 (횃대 자료 확인)" % [waiting["id"], int(WAIT_LIMIT)])
			waiting = {}
	cooldown -= delta
	if cooldown <= 0.0:
		cooldown = App.rng.randf_range(0.6, 2.2)
		if active_birds().size() < int(App.settings["bird_count"]):
			if waiting.is_empty() and App.rng.randf() < PASS_CHANCE:
				_spawn_passer(view)
			else:
				_spawn(view, false)


## 오기로 정한 새를 앉힌다. 정한 새가 없으면 새로 고르고, 자리가 없으면 그 새를 그대로 기다리게 둔다.
func _spawn(view: Rect2, instant: bool) -> Bird:
	if waiting.is_empty():
		waiting = next_species()
		waited = 0.0
	var s := find_spot(waiting, main.play_rect().grow(-MARGIN))   # 화면 요소에 가리지 않는 곳에만 앉는다
	if s.is_empty():
		return null
	var b := _make(waiting)
	waiting = {}
	b.spot = s["rect"]
	if instant:
		b.perch_now(s["at"], s["perch"]["kind"])
	else:
		b.arrive(_entry_point(view, s["at"]), s["at"], s["perch"]["kind"])
	return b


func _spawn_passer(view: Rect2) -> Bird:
	var sp := next_species()
	var from_left := App.rng.randf() < 0.5
	var y := App.rng.randf_range(view.position.y + 20.0, view.position.y + view.size.y * 0.6)
	var a := Vector2(view.position.x - 40.0 if from_left else view.end.x + 40.0, y)
	var b := Vector2(view.end.x + 40.0 if from_left else view.position.x - 40.0, y + App.rng.randf_range(-40.0, 40.0))
	var bird := _make(sp)
	bird.pass_through(a, b)
	return bird


func _make(sp: Dictionary) -> Bird:
	var b := Bird.new()
	b.setup(sp, mat)
	b.bird_cell = main.bird_cell()
	b.step = main.pixel_step()
	b.snap_cells = bool(App.settings["snap_motion"])
	layer.add_child(b)
	return b


func _occupied(r: Rect2) -> bool:
	for b in active_birds():
		if b.state == Bird.State.LEAVING or b.state == Bird.State.PASSING or not b.spot.has_area():
			continue   # 날아가는 새와 아직 자리가 없는 새(다시 앉히는 중)는 자리를 막지 않는다
		if b.spot.grow(-0.5).intersects(r):
			return true
	return false


## 들어오는 곳: 화면 밖 옆이나 위. 가까운 쪽에서 오는 일이 많다.
func _entry_point(view: Rect2, target: Vector2) -> Vector2:
	if App.rng.randf() < 0.2:
		return Vector2(target.x + App.rng.randf_range(-80.0, 80.0), view.position.y - 30.0)
	var near_left := target.x < view.get_center().x
	var from_left := near_left if App.rng.randf() < 0.7 else not near_left
	var x := view.position.x - 40.0 if from_left else view.end.x + 40.0
	var y := clampf(target.y - App.rng.randf_range(30.0, 120.0), view.position.y - 30.0, target.y - 8.0)
	return Vector2(x, y)


## 나가는 곳: 화면 밖 옆 위쪽.
func _exit_point(view: Rect2, from: Vector2) -> Vector2:
	var to_left := App.rng.randf() < 0.5
	var x := view.position.x - 60.0 if to_left else view.end.x + 60.0
	return Vector2(x, from.y - App.rng.randf_range(40.0, 140.0))
