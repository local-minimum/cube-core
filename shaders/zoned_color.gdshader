shader_type spatial;
render_mode unshaded;
render_mode depth_draw_opaque;
render_mode depth_prepass_alpha;
render_mode shadows_disabled;

uniform sampler2D main_tex: source_color, filter_nearest;
uniform vec3 dark_color: source_color;
uniform vec3 light_color: source_color;
uniform vec4 passthrough: source_color;
uniform float precision: hint_range(0.0, 1.0, 0.05);

void vertex() {}   

void fragment() {
    vec4 tex = texture(main_tex, UV);
    
    if (distance(tex, passthrough) < precision) {
        ALBEDO = tex.rgb;
    } else {
        float grey = 0.2126 * tex.r + 0.7152 * tex.g + 0.0722 * tex.b;
        ALBEDO = mix(dark_color, light_color, grey);
    }

    ALPHA = tex.a;
}