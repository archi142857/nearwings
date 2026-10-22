shader_type canvas_item;
// 월드 배경: 구운 그림 두 장(TEXTURE = 색표 A, tex_b = 색표 B)을 mix_ab만큼 섞는다.
// 칸마다 색만 다르므로 두 그림을 섞는 것은 색표를 섞는 것과 같다.
// 칸 경계 처리는 sharp_sprite와 같다 (이 노드는 선형 필터로 둔다).

uniform sampler2D tex_b : filter_linear, repeat_disable;
uniform float mix_ab : hint_range(0.0, 1.0) = 0.0;
uniform bool smooth_edges = true;

// fragment()의 COLOR에는 이미 기본 UV로 읽은 그림 색이 곱해져 있어서, 정점 색(modulate)만 따로 넘긴다.
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	highp vec2 size = vec2(textureSize(TEXTURE, 0));
	highp vec2 texel = UV * size;
	highp vec2 uv;
	if (smooth_edges) {
		highp vec2 px_per_texel = 1.0 / max(fwidth(texel), vec2(1e-6));
		highp vec2 t = texel - 0.5;
		highp vec2 base = floor(t);
		highp vec2 f = clamp((t - base - 0.5) * px_per_texel + 0.5, 0.0, 1.0);
		uv = (base + f + 0.5) / size;
	} else {
		uv = (floor(texel) + 0.5) / size;
	}
	vec4 c = texture(TEXTURE, uv);
	if (mix_ab > 0.0) {
		c = mix(c, texture(tex_b, uv), mix_ab);
	}
	COLOR = c * tint;
}
