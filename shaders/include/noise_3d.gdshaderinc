#ifndef NOISE_3D_INCLUDED
#define NOISE_3D_INCLUDED

// 格点白噪声、连续值噪声与三层分形噪声，输出范围均为 [0, 1]。
float noise_white_3d(vec3 cell) {
	vec3 p = fract(cell * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float noise_value_3d(vec3 p) {
	vec3 i = floor(p);
	vec3 w = fract(p);
	w = w * w * (3.0 - 2.0 * w);
	float front = mix(
		mix(noise_white_3d(i), noise_white_3d(i + vec3(1,0,0)), w.x),
		mix(noise_white_3d(i + vec3(0,1,0)), noise_white_3d(i + vec3(1,1,0)), w.x), w.y);
	float back = mix(
		mix(noise_white_3d(i + vec3(0,0,1)), noise_white_3d(i + vec3(1,0,1)), w.x),
		mix(noise_white_3d(i + vec3(0,1,1)), noise_white_3d(i + vec3(1,1,1)), w.x), w.y);
	return mix(front, back, w.z);
}

float noise_fbm_3d(vec3 p) {
	return (4.0 * noise_value_3d(p) + 2.0 * noise_value_3d(2.0 * p + 17.0)
			+ noise_value_3d(4.0 * p + 31.0)) / 7.0;
}
#endif
