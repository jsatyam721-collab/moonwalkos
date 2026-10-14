#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float power;
    vec2 size;
};

layout(binding = 1) uniform sampler2D source;

const float PI = 3.14159265;

void main() {
    vec2 q = qt_TexCoord0 * 2.0 - 1.0;
    float p = clamp(power, 0.0, 1.0);

    float sy = mix(0.004, 1.0, smoothstep(0.42, 1.0, p));
    float sx = mix(0.0025, 1.0, smoothstep(0.06, 0.42, p));
    vec2 qs = q / vec2(sx, sy);

    float inside = step(abs(qs.x), 1.0) * step(abs(qs.y), 1.0);
    vec3 col = texture(source, qs * 0.5 + 0.5).rgb * inside;

    float k = 1.0 - p;
    float crt = smoothstep(1.0, 0.8, p);
    col *= mix(1.0, 0.84 + 0.16 * sin(qt_TexCoord0.y * size.y * PI / 1.5), crt);
    col = mix(col, vec3(dot(col, vec3(0.3, 0.59, 0.11))), crt * 0.35);
    col *= 1.0 + k * 3.5;
    col = mix(col, vec3(0.92, 0.96, 1.0) * inside, smoothstep(0.55, 0.15, p));

    float px = 1.0 / size.y;
    float lineGlow = exp(-abs(q.y) / (px * 6.0 + sy * 0.5)) * smoothstep(0.5, 0.25, p) * smoothstep(0.0, 0.08, p);
    float spanX = exp(-max(abs(q.x) - sx, 0.0) * 18.0);
    col += vec3(0.75, 0.85, 1.0) * lineGlow * spanX * 0.9;

    float dot = exp(-length(q * vec2(size.x / size.y, 1.0)) * 90.0) * smoothstep(0.12, 0.0, p) * smoothstep(-0.05, 0.03, p);
    col += vec3(0.9, 0.95, 1.0) * dot * 2.0;

    col *= smoothstep(-0.02, 0.05, p) + dot;

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
