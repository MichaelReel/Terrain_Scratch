shader_type spatial;

void fragment() {
	ALBEDO = COLOR.rgb;
	float thinness = 10000.0;
	float alpha_x = max(1.0 / (thinness * UV.x), -1.0 / (thinness * (UV.x - 1.0)));
	float alpha_y = max(1.0 / (thinness * UV.y), -1.0 / (thinness * (UV.y - 1.0)));
	float alpha = max(alpha_x, alpha_y);
	ALPHA = alpha;
}