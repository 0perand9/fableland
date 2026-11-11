// What every backdrop pattern is given, and how it answers. Lengths are in
// pixels; a length meant in design units is multiplied by `unit`.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;       // seconds, at the speed the user chose
    float strength;   // how visible the pattern is; 1 is the usual amount
    float pull;       // how present the pointer is, 0 … 1
    float unit;       // pixels per design unit
    vec2 size;        // of the backdrop
    vec2 pointer;     // where the pointer is
    vec4 tintA;       // the popup's colours
    vec4 tintB;
    vec4 tintC;
};

// This pixel's position.
vec2 here() {
    return qt_TexCoord0 * size;
}

// 1 at the pointer, fading out around `reach` design units from it; 0 while
// the pointer is somewhere else.
float nearness(vec2 p, float reach) {
    vec2 d = (p - pointer) / (reach * unit);
    return pull * exp(-dot(d, d));
}

// How much of this pixel a stroke covers: `width` design units wide, its
// middle `away` pixels from here.
float stroke(float away, float width) {
    float edge = 0.5 * width * unit;
    return 1.0 - smoothstep(edge - 0.5, edge + 0.5, away);
}

// Colours this pixel, `coverage` (0 … 1) of the way.
void paint(vec3 color, float coverage) {
    float alpha = clamp(coverage * strength, 0.0, 1.0) * qt_Opacity;
    fragColor = vec4(color * alpha, alpha);
}
