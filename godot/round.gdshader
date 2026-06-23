shader_type canvas_item;

uniform float radius : hint_range(0.0, 1.0) = 0.5;
uniform float feather : hint_range(0.0, 0.5) = 0.05;
uniform vec2 center = vec2(0.5, 0.5);

void fragment() {
	//vec2 uv = UV - center;
	//float dist = length(uv);
	
	//if (dist > radius) {
		//discard;
	//}
	
	//COLOR.a = min(COLOR.a, 1.0 - smoothstep(radius - feather, radius, dist));

	vec2 delta = UV - center;
	float dist_sq = dot(delta, delta);
	float radius_sq = radius * radius;
	float feather_sq = max(0.0, (radius - feather) * (radius - feather));
	
	float alpha = 1.0 - smoothstep(feather_sq, radius_sq, dist_sq);
	
	COLOR.a = min(COLOR.a, alpha);
}