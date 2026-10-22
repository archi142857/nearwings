class_name SpeciesDB
extends RefCounted
## 종 목록(data/species.json)과 종마다의 그림.
## 그림 이름 규칙: <종ID>.png(기본 자세), <종ID>_fly1.png·_fly2.png(날개), <종ID>_swim.png(헤엄).
## 날개 그림이 없으면 비행 중에도 기본 자세를 쓴다(임시).

const BIRD_DIR := "res://assets/birds/"
const FLIGHT_TYPES := ["undulating", "direct", "slow"]

var list: Array[Dictionary] = []
var by_id := {}


func load_file(path: String) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for s: Dictionary in data["species"]:
		var id: String = s["id"]
		var tex := {"stand": load(BIRD_DIR + id + ".png"), "fly": [], "swim": null}
		for n in ["_fly1", "_fly2"]:
			if ResourceLoader.exists(BIRD_DIR + id + n + ".png"):
				tex["fly"].append(load(BIRD_DIR + id + n + ".png"))
		if ResourceLoader.exists(BIRD_DIR + id + "_swim.png"):
			tex["swim"] = load(BIRD_DIR + id + "_swim.png")
		s["tex"] = tex
		list.append(s)
		by_id[id] = s


## 그림 크기(새 칸). pose: stand, swim, fly
static func sprite_size(sp: Dictionary, pose: String) -> Vector2:
	var t: Texture2D = sp["tex"]["stand"]
	if pose == "swim" and sp["tex"]["swim"] != null:
		t = sp["tex"]["swim"]
	elif pose == "fly" and not sp["tex"]["fly"].is_empty():
		t = sp["tex"]["fly"][0]
	return Vector2(t.get_size())
