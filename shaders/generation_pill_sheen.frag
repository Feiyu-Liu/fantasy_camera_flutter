#include <flutter/runtime_effect.glsl>

// Loading sheen for the generation status pill.
//
// Four palette colours are warped by a rotating noise field and two offset
// sine waves, then blended so the boundaries never resolve into visible bands.
// Adapted from the technique in the `mesh_gradient` package, reimplemented here
// so the phase is driven by the pill's own transition controller rather than a
// second ticker, and so nothing outlives the widget.

#define S(a, b, t) smoothstep(a, b, t)

uniform vec2 uSize;
uniform float uTime;
uniform float uGrain;

uniform vec3 uColor1;
uniform vec3 uColor2;
uniform vec3 uColor3;
uniform vec3 uColor4;

out vec4 fragColor;

mat2 rot(float a) {
    float s = sin(a);
    float c = cos(a);
    return mat2(c, -s, s, c);
}

// Value noise (Inigo Quilez, CC BY-NC-SA 3.0).
vec2 hash(vec2 p) {
    p = vec2(dot(p, vec2(2127.1, 81.17)), dot(p, vec2(1269.5, 283.37)));
    return fract(sin(p) * 43758.5453);
}

float noise(in vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float n = mix(
        mix(dot(-1.0 + 2.0 * hash(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0)),
            dot(-1.0 + 2.0 * hash(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
        mix(dot(-1.0 + 2.0 * hash(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
            dot(-1.0 + 2.0 * hash(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x),
        u.y);
    return 0.5 + 0.5 * n;
}

float grainNoise(vec2 p) {
    return fract(sin(dot(p * -1.0, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    vec2 uv = FlutterFragCoord().xy / uSize;
    float ratio = uSize.x / uSize.y;

    vec2 tuv = uv - 0.5;

    // uTime arrives already wrapped to [0,1), so every term below is periodic
    // in it and the loop closes without a visible seam.
    float angle = 2.0 * 3.14159265 * uTime;

    // Turn a full circle over the loop, at a constant rate.
    //
    // An earlier version drove this angle from the noise field instead. That
    // made the rotation lurch: it sat nearly still for most of the loop and
    // then jumped, so the sheen read as slow even at a short period. A linear
    // turn moves 1.5°/frame at every instant, which is both smoother at the
    // peak and faster on average. The noise stays in the picture as a wobble
    // on top, so the drift keeps its organic feel without the stalling.
    float wobble = (noise(vec2(cos(angle) * 0.35, sin(angle) * 0.35)) - 0.5);
    tuv.y *= 1.0 / ratio;
    tuv *= rot(angle + radians(wobble * 60.0));
    tuv.y *= ratio;

    // The pill is far wider than it is tall, so the horizontal frequency is
    // raised to keep more than one colour on screen at a time. These terms are
    // linear in the phase, so they carry the visible travel without breaking up.
    tuv.x += sin(tuv.y * 5.0 + angle) / 18.0;
    tuv.y += sin(tuv.x * 7.5 + angle) / 9.0;

    vec3 layer1 = mix(uColor1, uColor2, S(-0.3, 0.2, (tuv * rot(radians(-5.0))).x));
    vec3 layer2 = mix(uColor3, uColor4, S(-0.3, 0.2, (tuv * rot(radians(-5.0))).x));
    vec3 blended = mix(layer1, layer2, S(0.5, -0.3, tuv.y));

    vec3 grained = blended + (blended * grainNoise(uv) * uGrain);

    fragColor = vec4(grained, 1.0);
}
