#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 res;
    float time;
    float pPanel;
    float pRip;
    float pStrip;
    vec4 cPanel;
    vec4 cInk;
    vec4 cStrip;
};

float hash(float x) {
    return fract(sin(x * 127.1) * 43758.5453);
}

float noise(float x) {
    float i = floor(x);
    float f = fract(x);
    return mix(hash(i), hash(i + 1.0), f * f * (3.0 - 2.0 * f));
}

float halftone(vec2 p, float cell, float amount) {
    vec2 q = mat2(0.7071, -0.7071, 0.7071, 0.7071) * p / cell;
    float d = length(fract(q) - 0.5);
    float r = clamp(amount, 0.0, 1.0) * 0.72;
    return 1.0 - smoothstep(r - 0.06, r + 0.06, d);
}

vec4 over(vec4 base, vec4 top, float a) {
    return mix(base, vec4(top.rgb, 1.0), a);
}

void main() {
    vec2 p = qt_TexCoord0 * res;
    float boil = floor(time * 12.0);
    vec4 col = vec4(0.0);

    float front = mix(-0.5 * res.x, 1.6 * res.x, pRip) - (p.x + p.y * 0.55);
    float swept = smoothstep(0.0, 1.5, front);
    float trail = halftone(p, 11.0, 1.0 + front / 140.0);
    col = over(col, cInk, max(swept, front < 0.0 ? trail * step(-140.0, front) : 0.0));

    vec2 a = vec2(0.40 * res.x, 0.36 * res.y);
    vec2 b = vec2(0.76 * res.x, -0.02 * res.y);
    vec2 dir = normalize(b - a);
    vec2 nrm = vec2(-dir.y, dir.x);
    float along = dot(p - a, dir);
    float jag = 16.0 * (noise(along * 0.045 + boil * 0.37) - 0.5) + 7.0 * (noise(along * 0.31 + boil * 1.3) - 0.5);
    float d = dot(p - a, nrm) + jag;
    float band = 1.0 - smoothstep(-0.8, 0.8, d);
    float dotsOnRed = halftone(p, 9.0, 1.0 + d / 70.0) * step(-70.0, d) * band;
    vec4 top = over(over(vec4(0.0), cPanel, band), cInk, dotsOnRed);
    col = mix(col, top, band * swept);

    float bulge = res.x * (0.255 + 0.05 * sin(3.14159 * p.y / res.y));
    float edgeX = mix(-0.06 * res.x, bulge, pPanel) + 3.0 * (noise(p.y * 0.08 + boil) - 0.5);
    float panel = 1.0 - smoothstep(edgeX - 0.8, edgeX + 0.8, p.x);
    float rim = (1.0 - smoothstep(edgeX - 6.0, edgeX - 4.5, p.x)) * panel;
    float tone = halftone(p, 8.0, 0.75 - length(p - vec2(0.0, res.y)) / (0.55 * res.y)) * 0.35;
    vec4 panelCol = mix(cPanel, cInk, max(tone, 1.0 - rim));
    col = over(col, panelCol, panel);

    float stripX = res.x - mix(-10.0, 0.035 * res.x, pStrip) - 7.0 * sin(p.y * 0.022 + time * 1.8) - 3.0 * sin(p.y * 0.07 - time * 2.6);
    float strip = smoothstep(stripX - 0.8, stripX + 0.8, p.x);
    float stripRim = 1.0 - smoothstep(stripX + 3.0, stripX + 4.5, p.x);
    col = over(col, mix(cStrip, cInk, stripRim), strip);

    fragColor = col * qt_Opacity;
}
