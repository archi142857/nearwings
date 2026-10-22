extends "res://tests/test_case.gd"
## 종 목록·그림·배경 세 벌·횃대 데이터가 서로 맞는지.

const HABITAT := "res://assets/habitats/urban_river_park"


func _db() -> SpeciesDB:
	var db := SpeciesDB.new()
	db.load_file("res://data/species.json")
	return db


func _perches(set_name: String) -> Perches:
	var p := Perches.new()
	p.load_file("%s/%s/perches.json" % [HABITAT, set_name])
	return p


func test_species_ids_and_sprites() -> void:
	var db := _db()
	eq(db.list.size(), 10, "0단계는 10종")
	var re := RegEx.create_from_string("^[a-z]+_[a-z]+$")
	for sp in db.list:
		var id: String = sp["id"]
		check(re.search(id) != null, "%s: ID는 소문자_소문자" % id)
		eq(String(sp["sci"]).to_lower().replace(" ", "_"), id, "%s: ID = 학명" % id)
		check(sp["tex"]["stand"] != null, "%s: 기본 자세 그림" % id)
		check(sp["flight"] in SpeciesDB.FLIGHT_TYPES, "%s: 비행 유형" % id)


func test_three_sets_exist_with_right_shapes() -> void:
	for set_name in Layout.SET_NAMES:
		var img: Image = (load("%s/%s/index.png" % [HABITAT, set_name]) as Texture2D).get_image()
		var s := img.get_size()
		match set_name:
			"portrait":
				check(s.y > s.x, "세로형은 세로가 길다 (%s)" % str(s))
			"square":
				eq(s.x, s.y, "정사각형")
			"landscape":
				check(s.x > s.y, "가로형은 가로가 길다 (%s)" % str(s))
		for palette in ["day", "dawn", "evening", "night"]:
			var baked: Texture2D = load("%s/%s/baked_%s.png" % [HABITAT, set_name, palette])
			eq(Vector2i(baked.get_size()), s, "%s: 구운 %s 그림 크기 = index 크기" % [set_name, palette])
			for g in ["ground", "ground_blur"]:   # 가방 메뉴의 발밑 바닥: 장면과 같은 폭, 화면 높이만큼은 내려갈 수 있게
				var tex: Texture2D = load("%s/%s/%s_%s.png" % [HABITAT, set_name, g, palette])
				eq(Vector2i(tex.get_size()), s, "%s: %s_%s 크기 = 장면 크기" % [set_name, g, palette])


func test_every_species_has_a_perch_kind_in_each_set() -> void:
	var db := _db()
	for set_name in Layout.SET_NAMES:
		var perches := _perches(set_name)
		for sp in db.list:
			var w := SpeciesDB.sprite_size(sp, "stand").x
			check(not perches.for_species(sp, w).is_empty(), "%s/%s: 이 벌에 앉을 곳이 있다" % [set_name, sp["id"]])


func test_perches_inside_scene() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for set_name in Layout.SET_NAMES:
		var size: Vector2 = Vector2((load("%s/%s/index.png" % [HABITAT, set_name]) as Texture2D).get_size())
		var scene := Rect2(Vector2.ZERO, size)
		for p in _perches(set_name).items:
			check(p["kind"] in Perches.KINDS, "%s/%s: 횃대 종류" % [set_name, p["id"]])
			check(scene.encloses(Perches.bounds(p)), "%s/%s: 장면 안" % [set_name, p["id"]])
			for i in 20:
				check(Perches.bounds(p).grow(0.001).has_point(Perches.point_on(p, rng)), "%s/%s: 고른 점이 횃대 위" % [set_name, p["id"]])


func test_palettes_cover_every_set() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HABITAT + "/palettes.json"))
	var day: Array = data["palettes"]["day"]
	for name in ["dawn", "evening", "night"]:
		check(data["palettes"].has(name), "%s 색표가 있다" % name)
		eq((data["palettes"][name] as Array).size(), day.size(), "%s 색 수가 낮과 같다" % name)
	for key in TimeOfDay.KEYS:
		check((data["order"] as Array).has(key[1]), "시간대 %s 색표가 order에 있다" % key[1])
	for set_name in Layout.SET_NAMES:
		var img: Image = (load("%s/%s/index.png" % [HABITAT, set_name]) as Texture2D).get_image()
		img.convert(Image.FORMAT_R8)
		var top := 0
		for y in range(0, img.get_height(), 3):
			for x in range(0, img.get_width(), 3):
				top = maxi(top, int(round(img.get_pixel(x, y).r * 255.0)))
		check(top < day.size(), "%s: 색 번호가 색표 안에 있다 (최대 %d, 색 %d개)" % [set_name, top, day.size()])
