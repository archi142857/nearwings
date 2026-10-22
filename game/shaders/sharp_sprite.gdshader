shader_type canvas_item;
// 픽셀 그림(새)을 정수가 아닌 배율로 그릴 때 칸 경계만 1화소 안에서 섞는다.
// 이 셰이더를 쓰는 노드는 texture_filter를 선형(LINEAR)으로 둔다.
// silhouette을 1로 두면 그림 모양만 한 색으로 칠한다 (도감에서 못 찾은 새).

uniform bool smooth_edges = true;
uniform float silhouette : hint_range(0.0, 1.0) = 0.0;
uniform vec4 silhouette_color : source_color = vec4(0.36, 0.32, 0.27, 1.0);

// fragment()의 COLOR에는 이미 기본 UV로 읽은 그림 색이 곱해져 있다. 그래서 정점 색(modulate)만 따로 넘긴다.
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
	c.rgb = mix(c.rgb, silhouette_color.rgb, silhouette);
	COLOR = c * tint;
}
