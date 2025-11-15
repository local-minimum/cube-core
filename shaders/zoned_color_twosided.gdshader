shader_type spatial;
render_mode unshaded;
render_mode depth_draw_opaque;
render_mode depth_prepass_alpha;
render_mode shadows_disabled;
render_mode cull_disabled;

uniform sampler2D main_tex: source_color, filter_nearest;
uniform vec3 dark_color: source_color;
uniform vec3 light_color: source_color;
uniform vec4 passthrough: source_color;
uniform vec4 passthrough_blend_color: source_color;
uniform float passthrough_blend: hint_range(0.0, 1.0, 0.01);
uniform float precision: hint_range(0.0, 1.0, 0.05);
uniform float darken_north_south: hint_range(0.0, 1.0, 0.025);

void vertex() {

}

void fragment() {
    vec4 tex = texture(main_tex, UV);

    vec3 world = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;

    if (distance(tex, passthrough) < precision) {
        vec3 col = tex.rgb;

        if (abs(world.z) > abs(world.x) && abs(world.z) > abs(world.y)) {
            col = vec3(
                max(tex.r - 0.7874 * darken_north_south, 0.0),
                max(tex.g - 0.2848 * darken_north_south, 0.0),
                max(tex.b - 0.9278 * darken_north_south, 0)
            );
        }
        ALBEDO = mix(col, passthrough_blend_color.rgb, passthrough_blend);
    } else {
        float grey = 0.2126 * tex.r + 0.7152 * tex.g + 0.0722 * tex.b;
        if (abs(world.z) > abs(world.x) && abs(world.z) > abs(world.y)) {
            grey = max(0, grey - darken_north_south);
        }
        ALBEDO = mix(dark_color, light_color, grey);
    }

    ALPHA = tex.a;
}