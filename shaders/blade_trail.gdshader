shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 light_color : source_color = vec4(0.78, 0.89, 0.91, 0.72);
// Shade the union once: bends/crossings cannot accumulate alpha.
uniform vec4 samples[64]; // local x, y, birth time, stroke distance
uniform int sample_count = 0;
uniform float clock_seconds = 0.0;
uniform float fade_seconds = 0.22;
uniform float visible_length = 320.0;
uniform float stroke_distance = 0.0;
uniform float trail_width = 32.0;
varying vec2 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	float coverage = 0.0;
	for (int i = 0; i < 63; i++) {
		if (i + 1 >= sample_count) { break; }
		vec4 a = samples[i];
		vec4 b = samples[i + 1];
		vec2 segment = b.xy - a.xy;
		float t = clamp(dot(local_position - a.xy, segment) / max(dot(segment, segment), 0.0001), 0.0, 1.0);
		float age = max(0.0, clock_seconds - mix(a.z, b.z, t));
		float life = 1.0 - smoothstep(0.0, fade_seconds, age);
		float behind = stroke_distance - mix(a.w, b.w, t);
		float tail = 1.0 - smoothstep(0.0, visible_length, behind);
		float strength = life * tail;
		float radius = max(0.5, trail_width * 0.5 * sqrt(strength));
		float distance_to_path = length(local_position - mix(a.xy, b.xy, t));
		float body = 1.0 - smoothstep(radius * 0.12, radius, distance_to_path);
		float core = 1.0 - smoothstep(radius * 0.08, radius * 0.32 + 0.7, distance_to_path);
		float alpha = (body * 0.24 + core * 0.46) * strength;
		coverage = max(coverage, alpha);
	}
	COLOR = vec4(light_color.rgb * COLOR.rgb, coverage * light_color.a * COLOR.a);
}
