shader_type canvas_item;
render_mode unshaded;

uniform float radius : hint_range(0.0, 1.0) = 0.5;
uniform float feather : hint_range(0.0, 0.5) = 0.05;

void fragment() {
    vec2 uv_min = REGION_RECT.xy;
    vec2 uv_max = REGION_RECT.xy + REGION_RECT.zw;
    vec2 local_uv = (UV - uv_min) / (uv_max - uv_min);
    
    vec2 delta = local_uv - vec2(0.5, 0.5);
    float dist_sq = dot(delta, delta);
    float radius_sq = radius * radius;
    float feather_sq = max(0.0, (radius - feather) * (radius - feather));
    float alpha = 1.0 - smoothstep(feather_sq, radius_sq, dist_sq);
    
    COLOR.a = min(COLOR.a, alpha);
}