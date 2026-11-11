#version 440
#extension GL_GOOGLE_include_directive : enable
#include "common.glsl"

// A Voronoi mesh: every point belongs to the nearest of a set of wandering
// sites, and the borders between their cells are drawn. The pointer is a lens
// that spreads the cells under it.
const float pitch = 86.0;   // design units between sites, on average

vec2 site(vec2 cell) {
    vec2 seed = fract(sin(vec2(dot(cell, vec2(127.1, 311.7)), dot(cell, vec2(269.5, 183.3)))) * 43758.5453);
    return 0.5 + 0.36 * sin(time * 0.3 + 6.2831853 * seed);
}

void main() {
    vec2 p = here();
    p -= (p - pointer) * 0.4 * nearness(p, 150.0);
    vec2 q = p / (pitch * unit);
    vec2 cell = floor(q), within = fract(q);

    // The nearest site …
    vec2 nearest = vec2(0.0), offset = vec2(0.0);
    float best = 8.0;
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            vec2 g = vec2(float(i), float(j));
            vec2 to = g + site(cell + g) - within;
            float d = dot(to, to);
            if (d < best) {
                best = d;
                nearest = to;
                offset = g;
            }
        }
    }
    // … and how far it is to the border with any other.
    float border = 8.0;
    for (int j = -2; j <= 2; j++) {
        for (int i = -2; i <= 2; i++) {
            vec2 g = offset + vec2(float(i), float(j));
            vec2 to = g + site(cell + g) - within;
            vec2 between = to - nearest;
            if (dot(between, between) > 0.00001)
                border = min(border, dot(0.5 * (nearest + to), normalize(between)));
        }
    }

    float edge = stroke(border * pitch * unit, 1.0);
    float node = 1.0 - smoothstep(0.0, 0.05, sqrt(best));
    float tone = fract(sin(dot(cell + offset, vec2(12.9898, 78.233))) * 43758.5453);
    vec3 color = mix(tintA.rgb, tintB.rgb, tone);
    paint(color, 0.34 * edge + 0.5 * node + 0.05 * tone);
}
