shader_type canvas_item;
render_mode unshaded;
// 로딩 화면: 까치 그림(칸 그림 두 장)을 칸 배율 scale로 그리고, 칸 좌표의 원(center, radius)이 바깥쪽으로만
// 부드럽게(edge) 퍼지며 드러낸다. 원 밖은 바탕색. front는 뒤 날개를 뺀 앞 층(아이콘과 같은 그림),
// full은 뒤 날개까지 그린 그림이고 back(뒤 날개 알파)만큼 섞는다. 칸 경계만 1화소 안에서 섞는다(sharp_sprite와 같은 방식).
// 화면 전체를 덮는 사각형에 쓰고, 화면 화소 = UV × view_size.

uniform sampler2D front_tex : filter_linear, repeat_disable;
uniform sampler2D full_tex : filter_linear, repeat_disable;
uniform vec2 view_size = vec2(1080.0, 2400.0);
uniform vec2 origin = vec2(0.0);        // 캔버스 칸 (0, 0) 모서리의 화면 화소
uniform float scale = 3.0;              // 칸당 화소
uniform vec2 center = vec2(0.0);        // 드러내는 원의 가운데 (칸)
uniform float radius = 64.0;            // 다 드러난 반지름 (칸)
uniform float edge = 0.0;               // 바깥쪽 부드러운 띠 (칸)
uniform float back = 0.0;               // 뒤 날개 알파
uniform vec4 paper : source_color = vec4(0.937255, 0.901961, 0.823529, 1.0);
uniform float fade = 1.0;               // 로딩 화면 전체 알파 (게임으로 넘어갈 때)
uniform bool smooth_edges = true;

vec3 cell_color(sampler2D tex, highp vec2 cell, highp vec2 size) {
	highp vec2 t;
	if (smooth_edges) {
		highp vec2 seam = floor(cell + 0.5);
		t = seam + clamp((cell - seam) * scale, -0.5, 0.5);
	} else {
		t = floor(cell) + 0.5;
	}
	return texture(tex, t / size).rgb;
}

void fragment() {
	highp vec2 p = UV * view_size;
	highp vec2 cell = (p - origin) / scale;
	highp vec2 size = vec2(textureSize(full_tex, 0));
	vec3 bird = mix(cell_color(front_tex, cell, size), cell_color(full_tex, cell, size), back);
	// 원 가장자리: 처음(edge = 0)에는 1화소만 섞어 시스템 스플래시처럼 또렷하다
	float aa = 1.0 / scale;
	float d = length(cell - center);
	float m = 1.0 - smoothstep(radius - aa * 0.5, radius + max(edge, aa * 0.5), d);
	COLOR = vec4(mix(paper.rgb, bird, m), fade);
}
