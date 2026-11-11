#version 440
#extension GL_GOOGLE_include_directive : enable
#include "common.glsl"

// Guilloché, the engraving on banknotes: two families of petalled rings
// turning against each other. The petals swell around the pointer, and the
// centre leans towards it.
float rings(float radius, float angle, float petals, float turn, float depth) {
    float along = (radius + depth * sin(petals * angle + turn)) / 30.0;
    return stroke(abs(fract(along + 0.5) - 0.5) / fwidth(along), 1.0);
}

void main() {
    vec2 p = here();
    vec2 centre = mix(0.5 * size, pointer, 0.18 * pull);
    vec2 q = (p - centre) / unit;
    float radius = length(q), angle = atan(q.y, q.x);
    float depth = 13.0 * (1.0 + 1.2 * nearness(p, 170.0));

    float first = rings(radius, angle, 6.0, time * 0.16, depth);
    float second = rings(radius, angle, 10.0, -time * 0.12, depth);
    // The middle, where the petals are too tight to draw, stays empty.
    float open = smoothstep(20.0, 90.0, radius);
    vec3 color = mix(tintA.rgb, tintB.rgb, second / (first + second + 0.001));
    paint(color, open * 0.24 * (first + second));
}
