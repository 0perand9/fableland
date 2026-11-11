#version 440
#extension GL_GOOGLE_include_directive : enable
#include "common.glsl"

// The contour lines of a slowly shifting landscape, as on a map. The pointer
// raises a hill under itself.
float terrain(vec2 q) {
    return sin(q.x * 1.7 + time * 0.10) * cos(q.y * 1.3 - time * 0.08)
        + 0.6 * sin((q.x + q.y) * 1.1 - time * 0.06)
        + 0.5 * cos(length(q - vec2(1.2, 0.4)) * 2.3 + time * 0.09);
}

void main() {
    vec2 p = here();
    float height = terrain(p / (260.0 * unit)) + 1.3 * nearness(p, 150.0);
    // Five lines to a unit of height; every fifth is drawn stronger.
    float level = height * 5.0;
    float line = stroke(abs(fract(level + 0.5) - 0.5) / fwidth(level), 1.0);
    float fifth = level / 5.0;
    float index = stroke(abs(fract(fifth + 0.5) - 0.5) / fwidth(fifth), 1.6);

    vec3 color = mix(tintB.rgb, tintA.rgb, smoothstep(-1.2, 1.6, height));
    paint(color, 0.24 * line + 0.36 * index);
}
