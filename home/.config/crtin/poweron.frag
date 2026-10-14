#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float power;
    vec2 size;
};

const float PI = 3.14159265;

void main() {
    vec2 q = qt_TexCoord0 * 2.0 - 1.0;
    float p = clamp(power, 0.0, 1.0);
    vec2 px = 2.0 / size;

    float hx = mix(px.x * 1.5, 1.0, smoothstep(0.10, 0.42, p));
    float hy = mix(px.y * 1.0, 1.0, smoothstep(0.42, 1.0, p));

    vec2 d = abs(q) - vec2(hx, hy);
    float inX = clamp(-d.x / (px.x * 1.5), 0.0, 1.0);
    float inY = clamp(-d.y / (px.y * 1.5), 0.0, 1.0);
    float inside = inX * inY * smoothstep(0.0, 0.06, p);

    float veil = 1.0 - smoothstep(0.45, 0.92, p);
    float scan = (0.5 + 0.5 * sin(qt_TexCoord0.y * size.y * PI / 1.5)) * 0.32 * (1.0 - smoothstep(0.75, 1.0, p));
    vec3 tint = vec3(0.86, 0.93, 1.0);

    float dist = length(max(d, 0.0) / px);
    float halo = exp(-dist / 7.0) * (1.0 - smoothstep(0.55, 0.95, p)) * smoothstep(0.0, 0.08, p);
    float bloom = exp(-dist / 40.0) * 0.35 * (1.0 - smoothstep(0.4, 0.8, p)) * smoothstep(0.0, 0.1, p);

    vec3 outsideCol = tint * (halo + bloom);
    float aIn = veil + scan * (1.0 - veil);
    vec3 cIn = tint * veil;

    vec3 c = mix(outsideCol, cIn, inside);
    float a = mix(1.0, aIn, inside);
    fragColor = vec4(c, a) * qt_Opacity;
}
