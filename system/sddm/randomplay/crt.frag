#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float power;
    float glitch;
    float shapeN;
    vec2 size;
    vec2 vidScale;
};

layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D osd;

const float PI = 3.14159265;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

vec3 video(vec2 uv) {
    vec2 v = (uv - 0.5) * vidScale + 0.5;
    if (v.x < 0.0 || v.x > 1.0 || v.y < 0.0 || v.y > 1.0) return vec3(0.0);
    return texture(source, v).rgb;
}

void main() {
    vec2 q = qt_TexCoord0 * 2.0 - 1.0;

    float s = pow(pow(abs(q.x), shapeN) + pow(abs(q.y), shapeN), 1.0 / shapeN);
    float px = 2.0 / min(size.x, size.y);
    float tube = clamp((1.0 - s) / px, 0.0, 1.0);
    if (tube <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    float pOn = clamp(power, 0.0, 1.0);
    float sy = mix(0.004, 1.0, smoothstep(0.45, 1.0, pOn));
    float sx = mix(0.003, 1.0, smoothstep(0.0, 0.45, pOn));
    vec2 qs = q / vec2(sx, sy);
    float lit = step(abs(qs.x), 1.0) * step(abs(qs.y), 1.0);
    float collapse = 1.0 + (1.0 - pOn) * 5.0;

    vec2 b = qs * (1.0 + 0.075 * dot(qs, qs));
    vec2 uv = b * 0.5 + 0.5;

    float line = floor(uv.y * size.y / 2.0);
    float wob = 0.0012 * sin(uv.y * 38.0 + time * 2.3) + 0.0007 * sin(uv.y * 210.0 - time * 7.0);
    float tear = glitch * (noise(vec2(line * 0.11, floor(time * 24.0))) - 0.5) * 0.09;
    float roll = fract(time * 0.09);
    float band = exp(-pow((uv.y - roll) * 22.0, 2.0));
    uv.x += wob + tear + band * 0.004 * sin(time * 40.0 + uv.y * 90.0);

    float ca = 0.0016 + glitch * 0.006 + band * 0.002;
    vec3 col;
    col.r = video(uv + vec2(ca, 0.0)).r;
    col.g = video(uv).g;
    col.b = video(uv - vec2(ca, 0.0)).b;

    float luma = dot(col, vec3(0.299, 0.587, 0.114));
    col = mix(vec3(luma), col, 1.12);
    col = pow(col, vec3(0.9)) * vec3(1.06, 1.02, 0.97) * 1.22;

    vec4 o = texture(osd, uv + vec2(0.0012, 0.0));
    vec4 oc = texture(osd, uv - vec2(0.0012, 0.0));
    col = mix(col, vec3(0.0), max(o.a, oc.a) * 0.35);
    col += vec3(o.r, 0.0, 0.0) + vec3(0.0, mix(o.g, oc.g, 0.5), oc.b);

    float stat = hash(uv * size + floor(time * 30.0));
    col = mix(col, vec3(stat), glitch * 0.55);
    col += band * 0.06 * stat;

    float scan = 0.86 + 0.14 * sin(uv.y * size.y * PI / 2.0);
    float tri = mod(floor(qt_TexCoord0.x * size.x), 3.0);
    vec3 mask = vec3(tri == 0.0 ? 1.06 : 0.94, tri == 1.0 ? 1.06 : 0.94, tri == 2.0 ? 1.06 : 0.94);
    col *= scan * mask;

    col += (hash(qt_TexCoord0 * size + fract(time) * 91.0) - 0.5) * 0.06;
    col *= 1.0 + 0.018 * sin(time * 113.0);

    float vig = 1.0 - smoothstep(0.55, 1.05, s);
    col *= mix(0.55, 1.0, vig);

    col *= lit * collapse;
    if (pOn < 0.45) col += lit * vec3(0.9, 0.95, 1.0) * (0.45 - pOn) * 2.0;

    float edge = smoothstep(0.86, 1.0, s);
    vec3 glass = vec3(0.035, 0.034, 0.038) * (1.0 - edge);
    col = max(col, glass);
    vec2 g = qt_TexCoord0 - vec2(0.18, 0.12);
    float glare = exp(-dot(g * vec2(1.0, 1.6), g * vec2(1.0, 1.6)) * 9.0) * 0.06;
    col += glare + edge * edge * vec3(0.02);
    col *= 1.0 - edge * 0.55;

    fragColor = vec4(col * tube, tube) * qt_Opacity;
}
