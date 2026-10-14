#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 tint;
    float glow;
};
layout(binding = 1) uniform sampler2D source;
void main() {
    vec4 c = texture(source, qt_TexCoord0);
    if (c.a < 0.004) { fragColor = vec4(0.0); return; }
    vec3 rgb = c.rgb / c.a;
    float l = dot(rgb, vec3(0.299, 0.587, 0.114));
    vec3 dark = tint.rgb * 0.30;
    vec3 lite = mix(tint.rgb, vec3(0.93, 1.0, 0.97), 0.6);
    vec3 col = mix(dark, tint.rgb, clamp(l / 0.55, 0.0, 1.0));
    col = mix(col, lite, clamp((l - 0.55) / 0.45, 0.0, 1.0));
    col *= 1.0 + glow;
    fragColor = vec4(col * c.a, c.a) * qt_Opacity;
}
