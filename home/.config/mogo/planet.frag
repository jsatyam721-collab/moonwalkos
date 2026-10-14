#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float rot;
    float px;
    float form;
};
layout(binding = 1) uniform sampler2D surface;
layout(binding = 2) uniform sampler2D emission;

const float PI = 3.14159265;
const float TILT = 0.30;

void main() {
    vec2 q = (qt_TexCoord0 - 0.5) / 0.4159;
    float rq = length(q);
    float tw = (1.0 - smoothstep(0.50, 1.0, form)) * 2.4 * pow(clamp(1.0 - rq, 0.0, 1.0), 1.2);
    float cs = cos(tw), sn = sin(tw);
    vec2 qs = vec2(q.x * cs - q.y * sn, q.x * sn + q.y * cs);
    float r2 = dot(q, q);
    float r = sqrt(r2);
    float edge = clamp((1.0 - r) / px, 0.0, 1.0);
    if (edge <= 0.0) { fragColor = vec4(0.0); return; }
    vec3 n = vec3(q.x, q.y, sqrt(max(0.0, 1.0 - r2)));
    vec3 ns = vec3(qs.x, qs.y, n.z);

    float c = cos(TILT), s = sin(TILT);
    vec3 t = vec3(ns.x * c - ns.y * s, ns.x * s + ns.y * c, ns.z);
    float lon = atan(t.x, t.z) + rot;
    float lat = asin(clamp(t.y, -1.0, 1.0));
    vec2 uv = vec2(fract(lon / (2.0 * PI) + 0.5), lat / PI + 0.5);
    vec2 du = dFdx(uv), dv = dFdy(uv);
    if (du.x > 0.5) du.x -= 1.0; if (du.x < -0.5) du.x += 1.0;
    if (dv.x > 0.5) dv.x -= 1.0; if (dv.x < -0.5) dv.x += 1.0;
    vec3 albedo = textureGrad(surface, uv, du, dv).rgb;
    float emis = textureGrad(emission, uv, du, dv).r;

    vec3 L = normalize(vec3(-0.62, -0.42, 0.66));
    float ndl = dot(n, L);
    float diffuse = clamp(ndl, 0.0, 1.0);
    float term = 0.5 + 0.5 * tanh(ndl * 5.0);
    float shade = 0.18 + 0.95 * (0.35 * term + 0.65 * pow(diffuse, 0.85));
    float limb = 0.35 + 0.65 * pow(n.z, 0.45);
    vec3 col = albedo * (0.45 + 0.55 * shade) * limb;

    vec3 H = normalize(L + vec3(0.0, 0.0, 1.0));
    col += pow(clamp(dot(n, H), 0.0, 1.0), 60.0) * 0.22 * vec3(0.85, 1.0, 0.93);
    float side = clamp(0.5 - 0.5 * dot(q, vec2(0.84, 0.54)) / max(r, 1e-4), 0.0, 1.0);
    col += pow(1.0 - n.z, 3.2) * vec3(0.326, 0.96, 0.664) * (0.08 + 0.92 * pow(side, 1.4)) * 0.95;

    col += emis * vec3(0.21, 0.62, 0.43) * (0.55 + 0.45 * pow(n.z, 0.6));
    float k = clamp((form - 0.52) / 0.40, 0.0, 1.0);
    vec2 np2 = n.xy * 7.0 + vec2(rot * 1.1, 0.0);
    vec2 ip = floor(np2), fp = fract(np2);
    fp = fp * fp * (3.0 - 2.0 * fp);
    float h00 = fract(sin(dot(ip, vec2(12.9898, 78.233))) * 43758.5453);
    float h10 = fract(sin(dot(ip + vec2(1, 0), vec2(12.9898, 78.233))) * 43758.5453);
    float h01 = fract(sin(dot(ip + vec2(0, 1), vec2(12.9898, 78.233))) * 43758.5453);
    float h11 = fract(sin(dot(ip + vec2(1, 1), vec2(12.9898, 78.233))) * 43758.5453);
    float nz2 = mix(mix(h00, h10, fp.x), mix(h01, h11, fp.x), fp.y);
    float dis = smoothstep(0.0, 0.35, k * 1.5 - rq + (nz2 - 0.5) * 0.3);
    vec3 outc = col * dis;
    float outa = dis;
    fragColor = vec4(outc * edge, outa * edge) * qt_Opacity;
}
