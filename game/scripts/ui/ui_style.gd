class_name UiStyle
extends RefCounted
## 화면 요소의 공통 모양: 색, 글꼴, 상자, 테마. 크기는 dp로 받아 화소로 바꾼다(1dp = density 화소).
## 색은 배경의 베이지 단계에서 가져왔다(디자인 캔버스 Pg_Tint, 시안의 뷰파인더·셔터).
## 글꼴은 임시로 갈무리11(OFL 1.1, KS X 1001 한글만 남긴 부분 글꼴)을 쓴다.

const INK := Color("2e2922")
const PAPER := Color("f6f1e6")
const SAND := Color("e8dfcc")
const LINE := Color("c9b896")
const BEIGE := [Color("f6f0e3"), Color("efe6d2"), Color("e2d5ba"), Color("d2c19f"), Color("bca985"), Color("a08d6c"), Color("6f6250")]
const FONT_PATH := "res://assets/fonts/Galmuri11-ksx1001.ttf"


static func dp(v: float, density: float) -> int:
	return maxi(1, int(round(v * density)))


static func box(color: Color, radius: int, pad: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	return sb


static func label(text: String, size_px := 0, color := INK) -> Label:
	var l := Label.new()
	l.text = text
	if size_px > 0:
		l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	return l


static func theme(density: float) -> Theme:
	var th := Theme.new()
	th.default_font = load(FONT_PATH)
	th.default_font_size = dp(13, density)
	th.set_color("font_color", "Label", INK)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
		th.set_color(c, "Button", INK)
	var r := dp(10, density)
	var p := dp(8, density)
	th.set_stylebox("normal", "Button", box(SAND, r, p))
	th.set_stylebox("hover", "Button", box(Color("efe6d2"), r, p))
	th.set_stylebox("pressed", "Button", box(LINE, r, p))
	th.set_stylebox("hover_pressed", "Button", box(LINE, r, p))
	th.set_stylebox("disabled", "Button", box(Color(SAND, 0.6), r, p))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	# 밀대: 굵은 줄과 손가락 크기의 손잡이
	var track := box(LINE, dp(4, density), 0)
	track.content_margin_top = dp(4, density)
	track.content_margin_bottom = dp(4, density)
	th.set_stylebox("slider", "HSlider", track)
	th.set_stylebox("grabber_area", "HSlider", box(Color("8a7a5c"), dp(4, density), 0))
	th.set_stylebox("grabber_area_highlight", "HSlider", box(Color("8a7a5c"), dp(4, density), 0))
	var knob := knob_texture(dp(26, density))
	th.set_icon("grabber", "HSlider", knob)
	th.set_icon("grabber_highlight", "HSlider", knob)
	# 스크롤 막대는 얇게
	th.set_stylebox("scroll", "VScrollBar", box(Color(LINE, 0.4), dp(3, density), 0))
	th.set_stylebox("grabber", "VScrollBar", box(BEIGE[5], dp(3, density), 0))
	return th


static func knob_texture(d: int) -> ImageTexture:
	var img := Image.create_empty(d, d, false, Image.FORMAT_RGBA8)
	var r := d * 0.5
	for y in d:
		for x in d:
			var dist := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			if dist <= r - 0.5:
				img.set_pixel(x, y, INK if dist > r - maxf(2.0, d * 0.12) else PAPER)
	return ImageTexture.create_from_image(img)


## 화면 가장자리에서 시스템 영역(노치, 제스처 막대)을 뺀 여백: x=왼쪽, y=위, z=오른쪽, w=아래.
static func insets() -> Vector4:
	if not OS.has_feature("mobile"):
		return Vector4.ZERO
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	return Vector4(safe.position.x, safe.position.y, screen.x - safe.end.x, screen.y - safe.end.y)


## 칸 느낌의 동그란 셔터 그림 (22×22칸): 바깥 테 가장 어두운 베이지, 안쪽 테, 가운데 밝은 베이지.
static func shutter_texture(pressed: bool) -> ImageTexture:
	var n := 22
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var c := (n - 1) * 0.5
	for y in n:
		for x in n:
			var d := Vector2(x - c, y - c).length()
			if d <= c + 0.35:
				var col: Color = BEIGE[6]
				if d <= c - 0.9:
					col = BEIGE[5]
				if d <= c - 1.9:
					col = BEIGE[2] if pressed else BEIGE[0]
				img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)
