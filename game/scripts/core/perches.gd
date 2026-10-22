class_name Perches
extends RefCounted
## 배경 한 벌의 횃대(새가 앉는 자리). 형식은 assets/habitats/<서식지>/<벌>/perches.json 참고.

const KINDS := ["branch", "lamp", "bench", "reed", "wire", "roof", "water", "shallow", "ground", "grass"]

var items: Array[Dictionary] = []


func load_file(path: String) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for p: Dictionary in data["perches"]:
		items.append(p)


## 이 새가 앉을 수 있는 횃대들.
func for_species(sp: Dictionary, width_cells: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p in items:
		if p["kind"] in sp["perches"] and width_cells <= float(p["max_w"]):
			out.append(p)
	return out


## 횃대 위의 한 점(발끝 자리)을 고른다.
static func point_on(p: Dictionary, rng: RandomNumberGenerator) -> Vector2:
	match p["shape"]:
		"point":
			return Vector2(p["a"][0], p["a"][1])
		"segment":
			var a := Vector2(p["a"][0], p["a"][1])
			var b := Vector2(p["b"][0], p["b"][1])
			return a.lerp(b, rng.randf())
		"area":
			var r: Array = p["rect"]
			return Vector2(rng.randf_range(r[0], r[2]), rng.randf_range(r[1], r[3]))
	return Vector2.ZERO


## 횃대 전체를 감싸는 사각형 (월드 칸).
static func bounds(p: Dictionary) -> Rect2:
	match p["shape"]:
		"area":
			var r: Array = p["rect"]
			return Rect2(r[0], r[1], r[2] - r[0], r[3] - r[1])
		"segment":
			var a := Vector2(p["a"][0], p["a"][1])
			var b := Vector2(p["b"][0], p["b"][1])
			return Rect2(a, Vector2.ZERO).expand(b)
	return Rect2(Vector2(p["a"][0], p["a"][1]), Vector2.ZERO)
