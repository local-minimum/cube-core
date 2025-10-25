shader_type spatial;
render_mode unshaded;
render_mode depth_draw_opaque;
render_mode depth_prepass_alpha;

uniform sampler2D main_tex;
uniform vec3 dark_color: source_color;
uniform vec3 light_color: source_color;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
    vec2 st = (vec2(ivec2( UV * float(12) ))+0.5)/float(12);
    vec4 tex = textureLod( main_tex, st, 0 );
    float grey =  0.2126 * tex.r + 0.7152 * tex.g + 0.0722 * tex.b;
    ALBEDO = mix(dark_color, light_color, grey);
    ALPHA = tex.a;
}