extends Node
## 자체 시험 (--selftest): 실제 입력을 흉내 내서 셔터, 배경 벌, 뷰파인더 옮기기, 도감, 뒤로 가기를 차례로 해 본다.
## 실행: tools/check.sh 가 가상 화면에서 돌린다. 하나라도 틀리면 종료 코드 1.
## --expect_set=<벌 이름>을 주면 그 화면에서 그 벌을 골랐는지도 본다.

var main: Node
var failures: Array[String] = []


func run(main_node: Node) -> void:
	main = main_node
	await _frames(15)
	var vs: Vector2 = main.view_px

	# 1. 앉은 새에 맞추고 셔터를 누르면 도감에 오른다 (앉은 새가 보일 때까지 최대 10초 기다린다)
	var target: Bird = null
	for wait in 600:
		for b in main.spawner.active_birds():
			if b.state == Bird.State.PERCHED and main.play_rect().encloses(b.drawn_rect()):
				target = b
				break
		if target != null:
			break
		await _frames(1)
	if target == null:
		failures.append("셔터: 화면 안에 앉은 새가 없어 시험하지 못했다")
	else:
		var r: Rect2 = target.drawn_rect()
		var cam_tl: Vector2 = main.camera.position - main.view_cells * 0.5
		main.capture_ui.move_finder_to((r.get_center() - cam_tl) * main.bg_px)
		var count_before: int = main.collection.found_count() + int(main.collection.entry(target.sp["id"]).get("count", 0))
		await _click(main.capture_ui.shutter.get_rect().get_center())
		var count_after: int = main.collection.found_count() + int(main.collection.entry(target.sp["id"]).get("count", 0))
		_check(count_after > count_before, "셔터: %s 찍기" % target.sp["ko"])

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
		_check(main.background.shown.has(want_phase), "시각 %s시 배경: %s를 그려야 하는데 %s" % [App.args["hour"], want_phase, str(main.background.shown)])
	_check(main.spawner.active_birds().size() <= BirdRules.MAX_BIRDS + 1, "새는 많아야 %d마리 (떠나는 새 하나 더)" % BirdRules.MAX_BIRDS)

	# 3. 화면을 밀어도 장면은 그대로다 (둘러보기 없음)
	var cam_before: Vector2 = main.camera.position
	await _drag(Vector2(vs.x * 0.75, vs.y * 0.6), Vector2(-vs.x * 0.4, -vs.y * 0.2))
	await _frames(10)
	_check(main.camera.position.distance_to(cam_before) < 0.01, "밀어도 장면이 움직이지 않는다")

	# 4. 빈 곳을 짧게 누르면 뷰파인더가 그 자리로 온다
	var fc0: Vector2 = main.capture_ui.finder.get_rect().get_center()
	var tap := Vector2(vs.x * (0.75 if fc0.x < vs.x * 0.5 else 0.25), vs.y * 0.45)
	await _click(tap)
	var fc: Vector2 = main.capture_ui.finder.get_rect().get_center()
	_check(fc.distance_to(tap) < maxf(vs.x, vs.y) * 0.12, "짧게 누르기: 뷰파인더 %s, 누른 곳 %s" % [str(fc.round()), str(tap.round())])

	# 5. 빈 곳을 누른 채 끌면 뷰파인더가 손가락을 따라온다
	var from := Vector2(vs.x * (0.25 if fc.x > vs.x * 0.5 else 0.75), vs.y * 0.35)
	var by := Vector2(0.0, vs.y * 0.15)
	await _drag(from, by)
	var after: Vector2 = main.capture_ui.finder.get_rect().get_center()
	_check(after.distance_to(from + by) < maxf(vs.x, vs.y) * 0.12, "빈 곳에서 끌기: 뷰파인더 %s, 손가락 %s" % [str(after.round()), str((from + by).round())])

	# 6. 뷰파인더를 잡고 끌면 따라온다 (화면 가운데 쪽으로 끌어 가장자리에 막히지 않게)
	var start: Vector2 = main.capture_ui.finder.get_rect().get_center()
	var move: Vector2 = (vs * 0.5 - start)
	if move.length() < vs.x * 0.1:
		move = Vector2(vs.x * 0.2, 0.0)
	await _drag(start, move)
	var moved: Vector2 = main.capture_ui.finder.get_rect().get_center()
	_check((moved - start).dot(move.normalized()) > move.length() * 0.5, "뷰파인더 끌기: %s → %s (끈 거리 %s)" % [str(start.round()), str(moved.round()), str(move.round())])

	# 7. 도감 버튼 → 도감이 열리고, 뒤로 가기로 닫힌다
	await _click(main.capture_ui.dex_btn.get_rect().get_center())
	_check(main.dex_ui.is_open(), "도감 열기")
	main.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(2)
	_check(not main.dex_ui.is_open(), "뒤로 가기로 도감 닫기")

	# 8. (--rotate) 화면을 돌리면 벌을 다시 고르고, 앉아 있던 새는 새 장면 안에 다시 앉는다
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

	for f in failures:
		printerr("자체 시험 실패: " + f)
	print("자체 시험 %s (배경 %s)" % ["통과" if failures.is_empty() else "실패 %d건" % failures.size(), main.scene_set])
	main.get_tree().quit(0 if failures.is_empty() else 1)


func _check(cond: bool, what: String) -> void:
	if not cond:
		failures.append(what)


func _frames(n: int) -> void:
	for i in n:
		await main.get_tree().process_frame


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
