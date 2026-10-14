#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    float aspect;
    vec2 origin;
};

layout(binding = 1) uniform sampler2D source;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 6; i++) {
        v += a * noise(p);
        p = p * 2.03 + vec2(1.7, 9.2);
        a *= 0.5;
    }
    return v;
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 p = vec2(uv.x * aspect, uv.y);
    vec2 o = vec2(origin.x * aspect, origin.y);

    float d = length(p - o) / length(vec2(aspect, 1.0));
    float n = fbm(p * 3.2);
    float field = d * 0.78 + n * 0.42;

    float t = mix(0.08, 1.16, progress);
    float edge = field - t;

    float flick = 0.75 + 0.5 * noise(p * 46.0 + vec2(progress * 31.0, -progress * 17.0));
    vec3 lit = vec3(1.0, 0.45, 0.08);

    if (edge <= 0.0) {
        float spill = 1.0 - smoothstep(0.0, 0.035, -edge);
        fragColor = vec4(lit * spill * 0.55 * flick, spill * 0.18) * qt_Opacity;
        return;
    }

    vec4 col = texture(source, uv);
    float ember = 1.0 - smoothstep(0.0, 0.022, edge);
    float glow = 1.0 - smoothstep(0.0, 0.06, edge);
    float scorch = 1.0 - smoothstep(0.0, 0.16, edge);

    vec3 c = col.rgb;
    c = mix(c, c * vec3(0.55, 0.42, 0.32), scorch * 0.9);
    c *= 1.0 - 0.75 * glow;

    vec3 hot = mix(vec3(0.95, 0.18, 0.02), vec3(1.0, 0.86, 0.42), ember * ember);
    c += hot * (ember * 1.7 + glow * 0.45) * flick;

    float a = smoothstep(0.0, 0.004, edge);
    fragColor = vec4(c * a, a) * qt_Opacity;
}
