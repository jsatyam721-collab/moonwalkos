#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    vec2 cen;
    float rad;
    vec2 emb;
    float form;
};

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

float hash3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float noise3(vec3 p) {
    vec3 i = floor(p), f = fract(p);
    vec3 u = f * f * (3.0 - 2.0 * f);
    float a = mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), u.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), u.x), u.y);
    float b = mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), u.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), u.x), u.y);
    return mix(a, b, u.z);
}
float fbm3(vec3 p) { return noise3(p) * 0.55 + noise3(p * 2.1) * 0.3 + noise3(p * 4.3) * 0.15; }

float field(vec2 p) {
    float t = form;
    float w = t * 9.0;
    float grow = smoothstep(0.18, 0.78, t);
    float rs = rad * (0.10 + 0.90 * grow);
    vec2 sc = cen + vec2(0.0, rad * 0.9 * (1.0 - grow));
    vec2 q = p - sc;
    float wob = 1.0 + 0.10 * (1.0 - grow * 0.85) * sin(atan(q.y, q.x) * 5.0 + w * 2.3) * sin(w * 1.7);
    float f = (rs * rs * wob) / max(dot(q, q), 1.0);

    vec2 b = cen + vec2(0.0, rad * 0.96);
    float drain = smoothstep(0.62, 0.95, t);
    for (int k = 0; k < 7; k++) {
        float fk = float(k);
        float s = clamp(t * 2.4 - fk * 0.13, 0.0, 1.0);
        if (s <= 0.0) continue;
        vec2 c = mix(emb, b, s);
        float hel = s * 13.0 + w * 2.6 + fk * 0.9;
        c.x += cos(hel) * (6.0 + 26.0 * s) * (1.0 - drain);
        float r = (13.0 - fk * 0.9) * (1.0 - drain) * (0.62 + 0.38 * (0.5 + 0.5 * sin(hel)));
        vec2 d = p - c;
        f += (r * r) / max(dot(d, d), 1.0);
    }
    vec2 de = p - emb;
    float re = 16.0 * (1.0 - smoothstep(0.35, 0.7, t));
    f += (re * re) / max(dot(de, de), 1.0);
    return f;
}

void main() {
    vec2 p = qt_TexCoord0 * size;
    float f = field(p);
    float e = 1.5;
    float fx = field(p + vec2(e, 0.0)) - field(p - vec2(e, 0.0));
    float fy = field(p + vec2(0.0, e)) - field(p - vec2(0.0, e));
    vec2 g = vec2(fx, fy) / (2.0 * e);
    float gl = length(g) + 1e-5;
    float w = form * 12.0;
    float sd = (f - 1.0) / gl;
    sd += (noise(p * 0.05 + vec2(w, -w * 0.7)) - 0.5) * 9.0;
    float a = smoothstep(-7.0, 3.0, sd);

    float grow = smoothstep(0.18, 0.78, form);
    float rs = rad * (0.10 + 0.90 * grow);
    vec2 sc = cen + vec2(0.0, rad * 0.9 * (1.0 - grow));
    vec2 v = (p - sc) / max(rs, 1.0);
    float vl = dot(v, v);
    vec3 n3 = vec3(v, sqrt(max(0.0, 1.0 - min(vl, 1.0))));
    float tx = 0.28;
    vec3 m = vec3(n3.x, n3.y * cos(tx) - n3.z * sin(tx), n3.y * sin(tx) + n3.z * cos(tx));
    float axisD = abs(v.x);
    float spin = w * 0.75;
    float th = atan(m.z, m.x) + spin;
    float hgt = -m.y;
    vec3 fp = vec3(cos(th) * 1.4, sin(th) * 1.4, hgt * 9.0);
    float fl = fbm3(fp + vec3(0.0, 0.0, fbm3(fp * 0.5 + w * 0.2) * 3.0));
    float fil = 1.0 - smoothstep(0.0, 0.035, abs(fract(fl * 4.0) - 0.5) - 0.0);
    fil *= smoothstep(0.3, 0.7, fbm3(fp * 1.7 + w * 0.15));
    float inSphere = smoothstep(1.03, 0.92, sqrt(vl));
    float thick = n3.z * inSphere;
    float bandC = hgt * 5.5 + th * 0.95;
    vec3 sp3 = vec3(cos(th) * 0.9, sin(th) * 0.9, bandC);
    float band = fbm3(sp3 + vec3(0.0, 0.0, fbm3(sp3 * vec3(2.0, 2.0, 0.6) + w * 0.25) * 1.2));
    float swirlB = smoothstep(0.50, 0.78, band);
    float grain = fbm3(vec3(cos(th) * 6.0, sin(th) * 6.0, bandC * 3.0) + w * 0.4);
    float core = exp(-axisD * axisD * 5.0);
    float swirlS = swirlB * (0.55 + 0.45 * grain) * inSphere * (0.35 + 0.65 * smoothstep(0.0, 0.5, n3.z)) * (0.55 + 0.75 * core);

    vec2 sdir = normalize(emb - (cen + vec2(0.0, rad)) + 1e-3);
    float lane = fbm3(vec3(dot(p, vec2(-sdir.y, sdir.x)) * 0.10, dot(p, sdir) * 0.025 - w * 1.6, w * 0.1));
    float jetLine = (1.0 - smoothstep(0.0, 0.05, abs(fract(lane * 3.0) - 0.5))) * (1.0 - inSphere);

    vec3 L1 = normalize(vec3(-0.55, -0.6, 0.6));
    vec3 L2 = normalize(vec3(0.6, 0.3, 0.75));
    vec3 nn = normalize(vec3(n3.xy + vec2(fl - 0.5) * 0.25, n3.z));
    float sp1 = pow(clamp(dot(nn, normalize(L1 + vec3(0, 0, 1))), 0.0, 1.0), 220.0);
    float sp2 = pow(clamp(dot(nn, normalize(L2 + vec3(0, 0, 1))), 0.0, 1.0), 60.0) * 0.25;
    float soft = pow(clamp(dot(nn, normalize(L1 + vec3(0, 0, 1))), 0.0, 1.0), 12.0) * 0.12;
    float fres = pow(1.0 - n3.z, 4.0) * inSphere;
    float caust = smoothstep(0.62, 0.9, fbm3(vec3(v * 3.0, w * 0.35))) * thick;

    float spray = 0.0;
    if (sd < 2.0 && sd > -30.0) {
        vec2 cp = p / 7.0 + vec2(floor(w * 3.0) * 1.7, 0.0);
        vec2 ci = floor(cp);
        vec2 jp = vec2(hash(ci), hash(ci + 17.3));
        float dd = length(fract(cp) - jp) * 7.0;
        spray = step(0.8, hash(ci + 3.1)) * exp(-dd * dd * 0.9) * smoothstep(-30.0, -3.0, sd) * (1.0 - smoothstep(0.8, 1.0, form));
    }

    vec3 absorb = exp(-thick * vec3(3.2, 0.9, 1.6));
    vec3 tint = vec3(0.10, 0.62, 0.42) * (1.0 - absorb.r) + vec3(0.02, 0.10, 0.07);
    vec3 hl = vec3(0.86, 1.0, 0.94);
    vec3 col = tint * (0.35 + 0.65 * thick) + hl * (swirlS * 0.85 + fil * 0.12 * thick + caust * 0.25 + jetLine * 0.4 + fres * 0.55 + soft) + vec3(1.0) * (sp1 * 1.8 + sp2) + hl * spray;
    float body = 0.05 + 0.13 * thick + 0.06 * (1.0 - inSphere);
    float fade = 1.0 - smoothstep(0.80, 1.0, form);
    float alpha = clamp(a * (body + swirlS * 0.42 + fil * 0.08 * thick + caust * 0.15 + jetLine * 0.3 + fres * 0.5 + sp1 + sp2 + soft) + spray * 0.6, 0.0, 1.0) * fade;
    fragColor = vec4(col * alpha, alpha) * qt_Opacity;
}
