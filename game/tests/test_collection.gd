extends "res://tests/test_case.gd"
## 도감 기록과 저장.

const PATH := "user://test_save.json"


func _fresh() -> Collection:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)
	var c := Collection.new()
	c.load_file(PATH)
	return c


func test_register_counts() -> void:
	var c := _fresh()
	var r1 := c.register("pica_serica", "2026-10-21")
	var r2 := c.register("pica_serica", "2026-10-22")
	check(r1["new"] and not r2["new"], "처음만 새로 찾은 것")
	eq(int(r2["count"]), 2, "두 번째 사진")
	eq(c.entry("pica_serica")["first"], "2026-10-21", "처음 찍은 날은 바뀌지 않는다")
	eq(c.found_count(), 1, "찾은 종 수")


func test_save_and_load_round_trip() -> void:
	var c := _fresh()
	c.register("parus_minor", "2026-10-21")
	c.register("anas_platyrhynchos", "2026-10-21")
	c.register("anas_platyrhynchos", "2026-10-21")
	check(c.save(), "저장 성공")
	var d := Collection.new()
	d.load_file(PATH)
	eq(d.found_count(), 2, "다시 읽은 종 수")
	eq(int(d.entry("anas_platyrhynchos")["count"]), 2, "다시 읽은 횟수")
	check(not FileAccess.file_exists(PATH + ".tmp"), "임시 파일이 남지 않는다")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	eq(saved.keys(), ["schema", "species"], "저장 파일 맨 위 항목")
	for id in saved["species"]:
		var keys: Array = (saved["species"][id] as Dictionary).keys()
		keys.sort()
		eq(keys, ["count", "first"], "%s: 날짜와 횟수만 (위치 값 없음)" % id)


func test_broken_or_old_file_is_ignored() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("{\"schema\": 99, \"species\": {\"x\": {}}}")
	f.close()
	var c := Collection.new()
	c.load_file(PATH)
	eq(c.found_count(), 0, "모르는 형식은 읽지 않는다")
	f = FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("not json")
	f.close()
	c.load_file(PATH)
	eq(c.found_count(), 0, "깨진 파일도 빈 도감으로")
	DirAccess.remove_absolute(PATH)
