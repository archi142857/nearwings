extends Node
## 자체 시험 (--selftest): 실제 입력을 흉내 내서 가방 메뉴, 카메라, 셔터, 뷰파인더, 도감, 뒤로 가기를 차례로 해 본다.
## 실행: tools/check.sh 가 가상 화면에서 돌린다. 하나라도 틀리면 종료 코드 1.
## --expect_set=<벌 이름>을 주면 그 화면에서 그 벌을 골랐는지도 본다. --rotate면 화면을 돌려 본다.

var main: Node
var failures: Array[String] = []


func run(main_node: Node) -> void:
	main = main_node
	await _frames(15)
	var vs: Vector2 = main.view_px
	var cu: CanvasLayer = main.capture_ui
	var bag: CanvasLayer = main.bag

	# 1. 기본 화면에는 뷰파인더와 셔터가 없고, 맨 아래에 가방 윗단이 보인다
	_check(not cu.finder.visible and not cu.shutter.visible, "기본 화면에는 뷰파인더와 셔터가 없다")
	_check(bag.is_closed() and bag.bag_rect_px().position.y < vs.y and bag.bag_rect_px().position.y > vs.y * 0.9, "맨 아래에 가방 윗단만 보인다")

	# 2. 배경 벌: 화면 비율에 맞는 벌을 골랐고, 장면이 화면을 꽉 채우며 가운데에 놓였다
	var want := String(App.args.get("expect_set", ""))
	if want != "":
		_check(main.scene_set == want, "배경 벌: %s를 골라야 하는데 %s" % [want, main.scene_set])
	var scene := Rect2(Vector2.ZERO, main.scene_cells)
	var view: Rect2 = main.view_rect()
	_check(scene.grow(0.01).encloses(view), "장면이 화면을 꽉 채운다: 장면 %s, 보이는 곳 %s" % [str(scene), str(view)])
	_check(view.get_center().distance_to(scene.get_center()) < 1.0, "보이는 곳이 장면 가운데: %s" % str(view.get_center()))
	if App.args.has("hour"):
		var want_phase := TimeOfDay.phase(float(App.args["hour"]))
		_check(main.background.shown().has(want_phase), "시각 %s시 배경: %s를 그려야 하는데 %s" % [App.args["hour"], want_phase, str(main.background.shown())])
	_check(main.spawner.active_birds().size() <= BirdRules.MAX_BIRDS + 1, "새는 많아야 %d마리 (떠나는 새 하나 더)" % BirdRules.MAX_BIRDS)

	# 3. 옆으로 밀거나 조금만 위로 밀면 장면은 그대로고 가방도 닫힌 채다
	var cam_before: Vector2 = main.camera.position
	await _drag(Vector2(vs.x * 0.8, vs.y * 0.5), Vector2(-vs.x * 0.5, -vs.y * 0.05))
	await _wait(0.6)
	_check(main.camera.position.distance_to(cam_before) < 0.01 and bag.is_closed(), "옆으로 밀어도 장면이 그대로다")
	await _drag(Vector2(vs.x * 0.5, vs.y * 0.55), Vector2(0.0, -vs.y * 0.12))
	await _until(func() -> bool: return bag.is_closed(), 3.0)
	_check(bag.is_closed() and main.camera.position.distance_to(cam_before) < 0.01, "1/4보다 덜 밀면 닫힌 채로 돌아온다")
	await _drag(Vector2(vs.x * 0.5, vs.y - 3.0), Vector2(0.0, -vs.y * 0.4))
	await _wait(0.6)
	_check(bag.is_closed(), "맨 아래 가장자리에서 시작한 밀기는 받지 않는다 (홈 제스처 자리)")

	# 4. 위로 밀면 가방이 열리고 시선이 화면 높이만큼 내려간다
	await _open_bag(vs)
	_check(bag.is_open(), "위로 밀면 가방이 열린다")
	_check(absf(main.camera.position.y - main.cam_base.y - main.view_cells.y) < 1.0, "시선이 화면 높이만큼 내려갔다")
	var top_share: float = bag.top_px() / vs.y
	_check(top_share > 0.4 and top_share < 0.6, "열린 가방은 화면 아래쪽 반쯤 (윗단 %.2f)" % top_share)

	# 5. 가방에서 도감을 누르면 도감이 열리고, 뒤로 가기로 닫으면 가방이 그대로 있다
	await _click(bag.item_center("dogam"))
	await _frames(3)
	_check(main.dex_ui.is_open(), "가방에서 도감 열기")
	main.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(2)
	_check(not main.dex_ui.is_open() and bag.is_open(), "뒤로 가기로 도감만 닫힌다")

	# 6. 카메라를 누르면 가방이 닫히고 뷰파인더와 셔터가 나온다
	await _click(bag.item_center("camera"))
	await _until(func() -> bool: return bag.is_closed(), 3.0)
	_check(main.tool == "camera" and cu.finder.visible and cu.shutter.visible, "카메라를 꺼내면 뷰파인더와 셔터가 나온다")
	_check(cu.shutter.get_rect().end.y <= bag.hint_top_px() + 1.0, "셔터는 가방 윗단·화살표 위에 있다")

	# 7. 앉은 새에 맞추고 셔터를 누르면 도감에 오른다 (앉은 새가 보일 때까지 최대 10초 기다린다)
	var target: Bird = null
	var waited := 0.0
	while target == null and waited < 10.0:
		for b in main.spawner.active_birds():
			if b.state == Bird.State.PERCHED and main.play_rect().encloses(b.drawn_rect()):
				target = b
				break
		if target == null:
			await _wait(0.2)
			waited += 0.2
	if target == null:
		failures.append("셔터: 화면 안에 앉은 새가 없어 시험하지 못했다")
	else:
		var r: Rect2 = target.drawn_rect()
		cu.move_finder_to((r.get_center() - main.view_rect().position) * main.bg_px)
		var count_before: int = main.collection.found_count() + int(main.collection.entry(target.sp["id"]).get("count", 0))
		await _click(cu.shutter.get_rect().get_center())
		var count_after: int = main.collection.found_count() + int(main.collection.entry(target.sp["id"]).get("count", 0))
		_check(count_after > count_before, "셔터: %s 찍기" % target.sp["ko"])

	# 8. 빈 곳을 짧게 누르면 뷰파인더가 그 자리로 온다
	var fc0: Vector2 = cu.finder.get_rect().get_center()
	var tap := Vector2(vs.x * (0.75 if fc0.x < vs.x * 0.5 else 0.25), vs.y * 0.45)
	await _click(tap)
	var fc: Vector2 = cu.finder.get_rect().get_center()
	_check(fc.distance_to(tap) < maxf(vs.x, vs.y) * 0.12, "짧게 누르기: 뷰파인더 %s, 누른 곳 %s" % [str(fc.round()), str(tap.round())])

	# 9. 빈 곳을 누른 채 아래로 끌면 뷰파인더가 손가락을 따라온다
	var from := Vector2(vs.x * (0.25 if fc.x > vs.x * 0.5 else 0.75), vs.y * 0.3)
	var by := Vector2(0.0, vs.y * 0.15)
	await _drag(from, by)
	var after: Vector2 = cu.finder.get_rect().get_center()
	_check(after.distance_to(from + by) < maxf(vs.x, vs.y) * 0.12, "빈 곳에서 끌기: 뷰파인더 %s, 손가락 %s" % [str(after.round()), str((from + by).round())])

	# 10. 뷰파인더를 잡고 끌면 따라온다 (위로 끌어도 가방이 열리지 않는다)
	var start: Vector2 = cu.finder.get_rect().get_center()
	var move := Vector2(vs.x * 0.5, vs.y * 0.3) - start
	if move.length() < vs.x * 0.1:
		move = Vector2(vs.x * 0.2, -vs.y * 0.05)
	await _drag(start, move)
	var moved: Vector2 = cu.finder.get_rect().get_center()
	_check((moved - start).dot(move.normalized()) > move.length() * 0.5 and bag.is_closed(), "뷰파인더 끌기: %s → %s (끈 거리 %s)" % [str(start.round()), str(moved.round()), str(move.round())])

	# 11. 가방을 열고 아래로 밀면 닫히고, 위쪽 흐린 바닥을 눌러도 닫힌다. 카메라는 그대로 들고 있다
	await _open_bag(vs)
	_check(not cu.finder.visible, "가방을 열면 뷰파인더와 셔터가 숨는다")
	await _drag(Vector2(vs.x * 0.5, vs.y * 0.25), Vector2(0.0, vs.y * 0.35))
	await _until(func() -> bool: return bag.is_closed(), 3.0)
	_check(bag.is_closed() and cu.finder.visible, "아래로 밀면 닫히고 카메라는 그대로")
	await _open_bag(vs)
	await _click(Vector2(vs.x * 0.5, bag.top_px() * 0.4))
	await _until(func() -> bool: return bag.is_closed(), 3.0)
	_check(bag.is_closed(), "흐린 바닥을 누르면 닫힌다")
	await _open_bag(vs)
	main.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await _until(func() -> bool: return bag.is_closed(), 3.0)
	_check(bag.is_closed(), "뒤로 가기로 가방이 닫힌다")

	# 12. 뒤로 가기: 든 도구를 넣으면 뷰파인더와 셔터가 사라진다
	main.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(2)
	_check(main.tool == "" and not cu.finder.visible and not cu.shutter.visible, "뒤로 가기로 카메라를 넣는다")

	# 13. (--rotate) 화면을 돌리면 벌과 가방 배치를 다시 고르고, 앉아 있던 새는 새 장면 안에 다시 앉는다
	if App.args.has("rotate"):
		var before_set: String = main.scene_set
		var size: Vector2i = main.get_tree().root.size
		main.get_tree().root.size = Vector2i(size.y, size.x)   # 기기를 돌린 것처럼 창 크기만 바꾼다
		await _frames(20)
		var want2 := Layout.choose_set(Vector2(size.y, size.x), main.set_sizes)
		_check(main.scene_set == want2, "돌린 뒤 배경 벌: %s → %s (기대 %s)" % [before_set, main.scene_set, want2])
		var scene2 := Rect2(Vector2.ZERO, main.scene_cells)
		var seated := 0
		for b in main.spawner.active_birds():
			if b.state == Bird.State.PERCHED:
				seated += 1
				_check(scene2.encloses(b.drawn_rect()), "돌린 뒤 %s가 장면 안에 앉아 있다" % b.sp["ko"])
		_check(seated > 0, "돌린 뒤에도 앉아 있는 새가 있다")
		var vs2: Vector2 = main.view_px
		await _open_bag(vs2)
		var br: Rect2 = bag.bag_rect_px()
		_check(bag.is_open() and br.position.x >= 0.0 and br.end.x <= vs2.x + 1.0, "돌린 뒤 가방이 화면 안에 열린다: %s" % str(br))

	for f in failures:
		printerr("자체 시험 실패: " + f)
	print("자체 시험 %s (배경 %s)" % ["통과" if failures.is_empty() else "실패 %d건" % failures.size(), main.scene_set])
	main.get_tree().quit(0 if failures.is_empty() else 1)


func _open_bag(vs: Vector2) -> void:
	await _drag(Vector2(vs.x * 0.5, vs.y * 0.62), Vector2(0.0, -vs.y * 0.36))
	await _until(func() -> bool: return main.bag.is_open() and main.bag.hop_t < 0.0, 4.0)


func _check(cond: bool, what: String) -> void:
	if not cond:
		failures.append(what)


func _frames(n: int) -> void:
	for i in n:
		await main.get_tree().process_frame


func _wait(sec: float) -> void:
	await main.get_tree().create_timer(sec).timeout


## cond가 참이 될 때까지 (최대 sec초) 기다린다.
func _until(cond: Callable, sec: float) -> void:
	var t := 0.0
	while not cond.call() and t < sec:
		await _wait(0.05)
		t += 0.05
	await _frames(2)


func _press(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	Input.parse_input_event(e)


func _move(pos: Vector2, rel: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.relative = rel
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(e)


func _click(pos: Vector2) -> void:
	_press(pos, true)
	await _frames(2)
	_press(pos, false)
	await _frames(3)


func _drag(from: Vector2, by: Vector2) -> void:
	_press(from, true)
	await _frames(2)
	var steps := 6
	for i in steps:
		_move(from + by * (i + 1) / steps, by / steps)
		await _frames(1)
	_press(from + by, false)
	await _frames(3)
