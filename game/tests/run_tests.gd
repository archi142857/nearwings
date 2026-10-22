extends SceneTree
## 단위 시험 실행기: res://tests/test_*.gd 안의 test_로 시작하는 함수를 모두 돌린다.
## 실행: godot --headless --path game -s res://tests/run_tests.gd  (실패가 있으면 종료 코드 1)


func _init() -> void:
	var total := 0
	var failed: Array[String] = []
	var files := DirAccess.get_files_at("res://tests")
	files.sort()
	for f in files:
		if not f.begins_with("test_") or not f.ends_with(".gd") or f == "test_case.gd":
			continue
		var script: GDScript = load("res://tests/" + f)
		for m in script.get_script_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
			var inst: Object = script.new()
			inst.set("current", f.get_basename() + "." + name)
			inst.call(name)
			total += 1
			failed.append_array(inst.get("failures"))
	for msg in failed:
		printerr("실패 " + msg)
	print("단위 시험 %d개, 실패 %d건" % [total, failed.size()])
	quit(1 if failed.size() > 0 else 0)
