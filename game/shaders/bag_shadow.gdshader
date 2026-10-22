shader_type canvas_item;
render_mode blend_mul;
// 가방 둘레 바닥 그림자 (디자인 배치값 'bag_shadow_on_ground'): 가방 모양(직사각형)을 grow만큼 넓혀
// 표준편차 sigma로 흐린 것을 strength만큼 바닥에 곱한다. 단위는 이 노드의 좌표(가방 칸), 가방 왼쪽 위가 원점.
// 직사각형을 가우스로 흐린 값은 가로·세로 오차 함수의 곱이라 그 자리에서 바로 셈한다.

uniform vec2 rect_size = vec2(206.0, 248.0);
uniform float grow = 0.8;
uniform float sigma = 3.2;
uniform float strength = 0.07;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

// Abramowitz–Stegun 7.1.26 (오차 1.5e-7)
float erf_approx(float x) {
	float s = sign(x);
	float a = abs(x);
	float t = 1.0 / (1.0 + 0.3275911 * a);
	float y = 1.0 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t * exp(-a * a);
	return s * y;
}

void fragment() {
	vec2 lo = vec2(-grow);
	vec2 hi = rect_size + vec2(grow);
	float k = 1.0 / (sigma * 1.41421356);
	float sx = 0.5 * (erf_approx((local.x - lo.x) * k) - erf_approx((local.x - hi.x) * k));
	float sy = 0.5 * (erf_approx((local.y - lo.y) * k) - erf_approx((local.y - hi.y) * k));
	COLOR = vec4(vec3(1.0 - strength * sx * sy), 1.0);
}
