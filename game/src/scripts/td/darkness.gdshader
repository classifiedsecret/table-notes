shader_type canvas_item;
// The dark of the Goblin Warren, drawn over the room. Each light is (x, y, radius, kind):
// kind 0 = firelight (warm, full colour), 1 = darkvision (sight without colour), 2 = cool glow.
// Outside every light only a faint shape of the room shows.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec4 lights[32];
uniform int light_count = 0;
uniform float ambient = 0.10;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float warm = 0.0;
	float sight = 0.0;
	float cool = 0.0;
	for (int i = 0; i < 32; i++) {
		if (i >= light_count) break;
		vec4 l = lights[i];
		float d = distance(world_pos, l.xy);
		float f = 1.0 - smoothstep(l.z * 0.45, l.z, d);
		if (l.w < 0.5) {
			warm = max(warm, f);
		} else if (l.w < 1.5) {
			sight = max(sight, f);
		} else {
			cool = max(cool, f * 0.8);
		}
	}
	float grey = dot(c, vec3(0.3, 0.59, 0.11));
	vec3 col = c * ambient;
	// Darkvision: dim light, almost no colour.
	col = mix(col, mix(vec3(grey), c, 0.2) * 0.72, sight);
	col = mix(col, c * vec3(0.75, 0.95, 1.0), cool);
	col = mix(col, c * vec3(1.05, 0.97, 0.86), warm);
	COLOR = vec4(col, 1.0);
}
