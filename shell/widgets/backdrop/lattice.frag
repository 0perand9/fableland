#version 440
#extension GL_GOOGLE_include_directive : enable
#include "common.glsl"

// A lattice of dots. A slow wave passes through it; the dots around the
// pointer swell and lean away from it.
void main() {
    vec2 p = here();
    float pitch = 22.0 * unit;
    vec2 cell = floor(p / pitch);
    vec2 centre = (cell + 0.5) * pitch;

    float wave = 0.5 + 0.5 * sin(dot(cell, vec2(0.42, 0.27)) - time * 0.9);
    float close = nearness(centre, 110.0);
    vec2 away = centre - pointer;
    centre += away / (length(away) + 0.001) * close * 5.0 * unit;

    float radius = unit * (0.8 + 0.9 * wave + 2.0 * close);
    float dot_ = 1.0 - smoothstep(radius - 0.6, radius + 0.6, distance(p, centre));
    vec3 color = mix(mix(tintB.rgb, tintA.rgb, wave), tintC.rgb, close);
    paint(color, dot_ * (0.22 + 0.4 * wave + 0.45 * close));
}
