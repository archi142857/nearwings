class_name Collection
extends RefCounted
## 도감 기록: 종마다 처음 찍은 날(날짜만)과 찍은 횟수. 기기 안의 JSON 파일 하나에 저장한다.
## 위치 관련 값은 넣지 않는다(결정 기록 권장). 2단계 위젯도 같은 파일을 읽고 쓸 수 있게 단순한 JSON으로 둔다.
## 형식: {"schema": 1, "species": {"pica_serica": {"first": "2026-10-21", "count": 3}}}

const SCHEMA := 1
const DEFAULT_PATH := "user://save.json"

var path := DEFAULT_PATH
var species := {}


func load_file(p: String = DEFAULT_PATH) -> void:
	path = p
	species = {}
	if not FileAccess.file_exists(p):
		return
	var json := JSON.new()   # 깨진 파일이어도 오류를 띄우지 않고 빈 도감으로 시작한다
	if json.parse(FileAccess.get_file_as_string(p)) != OK:
		return
	var parsed: Variant = json.data
	if parsed is Dictionary and int(parsed.get("schema", 0)) == SCHEMA and parsed.get("species") is Dictionary:
		for id: String in parsed["species"]:
			var e: Dictionary = parsed["species"][id]
			species[id] = {"first": String(e.get("first", "")), "count": int(e.get("count", 1))}


## 임시 파일에 쓴 뒤 바꿔치기해서, 쓰다가 꺼져도 이전 기록이 남게 한다.
func save() -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({"schema": SCHEMA, "species": species}, " ", true))
	f.close()
	return DirAccess.rename_absolute(tmp, path) == OK


## 한 번 찍힌 것을 기록한다. 돌려주는 값: {"new": 처음인지, "count": 지금까지 횟수}
func register(id: String, date: String) -> Dictionary:
	var is_new := not species.has(id)
	if is_new:
		species[id] = {"first": date, "count": 0}
	species[id]["count"] = int(species[id]["count"]) + 1
	return {"new": is_new, "count": species[id]["count"]}


func is_found(id: String) -> bool:
	return species.has(id)


func found_count() -> int:
	return species.size()


func entry(id: String) -> Dictionary:
	return species.get(id, {})


static func today() -> String:
	return Time.get_date_string_from_system()
