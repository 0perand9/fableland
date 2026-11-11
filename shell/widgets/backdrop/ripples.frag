#version 440
#extension GL_GOOGLE_include_directive : enable
#include "common.glsl"

// Circular waves from two wandering sources meet and cancel; the pointer is a
// third source. Drawn are the still lines between crest and trough, with a
// faint light where crests pile up.
float ripple(vec2 p, vec2 source, float phase) {
    float d = distance(p, source) / unit;
    return sin(d * 0.085 - time * 1.1 + phase) * exp(-d * 0.0016);
}

void main() {
    vec2 p = here();
    vec2 a = size * (0.5 + 0.34 * vec2(cos(time * 0.13), sin(time * 0.17)));
    vec2 b = size * (0.5 + 0.38 * vec2(cos(time * 0.11 + 2.4), sin(time * 0.09 + 1.1)));
    float surface = ripple(p, a, 0.0) + ripple(p, b, 1.9) + 1.4 * pull * ripple(p, pointer, 0.6);

    float still = stroke(abs(surface) / fwidth(surface), 1.0);
    float crest = smoothstep(0.5, 2.2, surface);
    vec3 color = mix(tintB.rgb, tintA.rgb, 0.5 + 0.3 * surface);
    paint(color, 0.36 * still + 0.16 * crest);
}
